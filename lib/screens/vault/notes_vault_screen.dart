import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/vault_note.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../ui/vault_theme.dart';

/// The vault's notes: a list, newest first, pinned notes on top.
class NotesPane extends StatefulWidget {
  const NotesPane({super.key});

  @override
  State<NotesPane> createState() => NotesPaneState();
}

class NotesPaneState extends State<NotesPane> {
  List<VaultNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;
    final notes = <VaultNote>[];
    for (final item in vault.items.where((i) => i.type == VaultItemType.note)) {
      final data = await VaultService.getItemData(vault, password, item.id, key: state.currentKey);
      if (data == null) continue;
      try {
        notes.add(VaultNote.decode(data));
      } catch (_) {
        // A note that cannot be read is left in place, untouched.
      }
    }
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  List<VaultNote> get _sorted => [..._notes]
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  /// Saves [note] as a new encrypted item, replacing its old one if any.
  Future<void> _store(VaultNote note) async {
    final state = context.read<AppState>();
    final password = state.currentPassword;
    if (state.currentVault == null || password == null) return;
    final old = state.currentVault!.items
        .where((i) => i.type == VaultItemType.note && i.name == note.id)
        .toList();
    await VaultService.addItem(
      vault: state.currentVault!,
      password: password,
      type: VaultItemType.note,
      name: note.id,
      data: note.encode(),
      key: state.currentKey,
    );
    for (final item in old) {
      await VaultService.deleteItem(state.currentVault!, password, item.id);
    }
    await state.refreshVault();
  }

  Future<void> _remove(VaultNote note) async {
    final state = context.read<AppState>();
    final password = state.currentPassword;
    if (state.currentVault == null || password == null) return;
    final items = state.currentVault!.items
        .where((i) => i.type == VaultItemType.note && i.name == note.id)
        .toList();
    for (final item in items) {
      await VaultService.deleteItem(state.currentVault!, password, item.id);
    }
    await state.refreshVault();
    if (mounted) setState(() => _notes.removeWhere((n) => n.id == note.id));
  }

  void create() {
    final note = VaultNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      content: '',
      updatedAt: DateTime.now(),
    );
    _edit(note, isNew: true);
  }

  void _edit(VaultNote note, {bool isNew = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VaultNoteEditor(
        note: note,
        isNew: isNew,
        onSave: (updated) async {
          setState(() {
            _notes.removeWhere((n) => n.id == updated.id);
            _notes.add(updated);
          });
          await _store(updated);
        },
        onDelete: () => _remove(note),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    if (_loading) return const SizedBox.shrink();
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 40, color: c.muted),
              const SizedBox(height: 12),
              Text('No notes yet', style: text.titleMedium!.copyWith(color: c.muted)),
            ],
          ),
        ),
      );
    }

    final notes = _sorted;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final note = notes[i];
        final preview = note.content.trim().split('\n').first;
        return Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _edit(note),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.tag != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 12),
                      child: CircleAvatar(radius: 5, backgroundColor: note.tag),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title.isEmpty ? 'Untitled' : note.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium!.copyWith(color: c.muted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_when(note.updatedAt), style: text.bodySmall),
                      if (note.isPinned) ...[
                        const SizedBox(height: 6),
                        Icon(Icons.push_pin, size: 16, color: c.muted),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _when(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return d.year == now.year ? '${d.day} ${months[d.month - 1]}' : '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class VaultNoteEditor extends StatefulWidget {
  const VaultNoteEditor({
    super.key,
    required this.note,
    required this.onSave,
    required this.onDelete,
    this.isNew = false,
  });

  final VaultNote note;
  final bool isNew;
  final Future<void> Function(VaultNote) onSave;
  final VoidCallback onDelete;

  @override
  State<VaultNoteEditor> createState() => _VaultNoteEditorState();
}

class _VaultNoteEditorState extends State<VaultNoteEditor> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _content = TextEditingController(text: widget.note.content);
  late int _color = widget.note.colorIndex;
  late bool _pinned = widget.note.isPinned;
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  /// Saves on the way out, by the back arrow or the system back gesture.
  void _commit() {
    if (_done) return;
    _done = true;
    final title = _title.text.trim();
    final content = _content.text;
    if (widget.isNew && title.isEmpty && content.trim().isEmpty) return;
    final changed = title != widget.note.title ||
        content != widget.note.content ||
        _color != widget.note.colorIndex ||
        _pinned != widget.note.isPinned;
    if (!changed) return;
    widget.onSave(VaultNote(
      id: widget.note.id,
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      colorIndex: _color,
      isPinned: _pinned,
    ));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.vault.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _done = true;
    if (!widget.isNew) widget.onDelete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          actions: [
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin',
              onPressed: () => setState(() => _pinned = !_pinned),
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            ),
            PopupMenuButton<int>(
              tooltip: 'Colour',
              icon: VaultNote.tags[_color] == const Color(0x00000000)
                  ? const Icon(Icons.circle_outlined)
                  : Icon(Icons.circle, color: VaultNote.tags[_color]),
              onSelected: (i) => setState(() => _color = i),
              itemBuilder: (context) => [
                for (var i = 0; i < VaultNote.tags.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        i == 0
                            ? Icon(Icons.circle_outlined, color: c.muted)
                            : Icon(Icons.circle, color: VaultNote.tags[i]),
                        if (i == _color) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.check, color: c.ink, size: 18),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              TextField(
                controller: _title,
                autofocus: widget.isNew,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _content,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Write something',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
