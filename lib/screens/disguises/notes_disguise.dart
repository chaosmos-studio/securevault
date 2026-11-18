import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/disguise_menu.dart';
import '../../ui/text_prompt.dart';
import 'disguise_screen.dart';
import 'pulse.dart';

class DisguiseNote {
  DisguiseNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.colorIndex = 0,
    this.isPinned = false,
  });

  String id;
  String title;
  String content;
  DateTime updatedAt;
  int colorIndex;
  bool isPinned;

  /// Note colours by index, as saved since 1.0. Index 0 is no colour.
  static const List<Color> lightColors = [
    Color(0x00000000),
    Color(0xFFFAAFA8),
    Color(0xFFF39F76),
    Color(0xFFFFF8B8),
    Color(0xFFE2F6D3),
    Color(0xFFB4DDD3),
    Color(0xFFD4E4ED),
    Color(0xFFAECCDC),
    Color(0xFFD3BFDB),
    Color(0xFFF6E2DD),
    Color(0xFFE9E3D4),
    Color(0xFFEFEFF1),
  ];

  static const List<Color> darkColors = [
    Color(0x00000000),
    Color(0xFF77172E),
    Color(0xFF692B17),
    Color(0xFF7C4A03),
    Color(0xFF264D3B),
    Color(0xFF0C625D),
    Color(0xFF256377),
    Color(0xFF284255),
    Color(0xFF472E5B),
    Color(0xFF6C394F),
    Color(0xFF4B443A),
    Color(0xFF232427),
  ];

  Color colorFor(Brightness b) {
    final colors = b == Brightness.dark ? darkColors : lightColors;
    return colors[colorIndex % colors.length];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'colorIndex': colorIndex,
        'isPinned': isPinned,
      };

  factory DisguiseNote.fromJson(Map<String, dynamic> json) => DisguiseNote(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        colorIndex: json['colorIndex'] as int? ?? 0,
        isPinned: json['isPinned'] as bool? ?? false,
      );
}

ThemeData notesTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFFE8A600),
      fontFamily: 'Roboto',
    ).copyWith(
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white,
    );

/// A notes app. Searching for a vault password opens the vault, and so do
/// five quick taps on the title and a new note titled with the password.
class NotesDisguise extends StatefulWidget {
  const NotesDisguise({super.key, this.coach = false});

  final bool coach;

  @override
  State<NotesDisguise> createState() => _NotesDisguiseState();
}

class _NotesDisguiseState extends State<NotesDisguise> {
  static const _storageKey = 'disguise_notes';

  List<DisguiseNote> _notes = [];
  bool _grid = true;
  String _query = '';
  final _search = TextEditingController();
  Timer? _searchCheck;
  int _titleTaps = 0;
  DateTime? _lastTitleTap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCheck?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || !mounted) return;
    final list = json.decode(raw) as List;
    setState(() {
      _notes = list
          .map((n) => DisguiseNote.fromJson(n as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, json.encode(_notes.map((n) => n.toJson()).toList()));
  }

  List<DisguiseNote> get _visible {
    final q = _query.toLowerCase();
    final notes = _notes
        .where((n) =>
            q.isEmpty ||
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return notes;
  }

  void _onSearch(String value) {
    setState(() => _query = value);
    _searchCheck?.cancel();
    _searchCheck = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      if (await tryVaultCode(context, value)) {
        _search.clear();
      }
    });
  }

  void _onTitleTap() {
    final now = DateTime.now();
    final quick = _lastTitleTap != null &&
        now.difference(_lastTitleTap!).inMilliseconds < 500;
    _titleTaps = quick ? _titleTaps + 1 : 1;
    _lastTitleTap = now;
    if (_titleTaps >= 5) {
      _titleTaps = 0;
      _showCodeDialog();
    }
  }

  Future<void> _showCodeDialog() async {
    final code = await askText(context, title: 'Enter code', confirm: 'Open', obscure: true);
    if (code != null && mounted) await tryVaultCode(context, code);
  }

  void _open(DisguiseNote note, {bool isNew = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Theme(
        data: notesTheme(Theme.of(context).brightness),
        child: DisguiseNoteEditor(
          note: note,
          isNew: isNew,
          onSave: (updated) {
            setState(() {
              final i = _notes.indexWhere((n) => n.id == updated.id);
              if (i == -1) {
                _notes.insert(0, updated);
              } else {
                _notes[i] = updated;
              }
            });
            _save();
          },
          onDelete: () {
            setState(() => _notes.removeWhere((n) => n.id == note.id));
            _save();
          },
        ),
      ),
    ));
  }

  void _create() {
    _open(
      DisguiseNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        content: '',
        updatedAt: DateTime.now(),
      ),
      isNew: true,
    );
  }

  Future<void> _showOptions(DisguiseNote note) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'pin') {
      setState(() => note.isPinned = !note.isPinned);
      _save();
    } else if (action == 'delete') {
      setState(() => _notes.removeWhere((n) => n.id == note.id));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: notesTheme(brightness),
      child: Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final notes = _visible;
        final searchBar = Container(
          height: 52,
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? const Color(0xFF303134)
                : const Color(0xFFF1F3F4),
            borderRadius: BorderRadius.circular(26),
          ),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              hintText: 'Search notes',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _onSearch('');
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        );

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _onTitleTap,
                        child: const Text(
                          'Notes',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _grid ? 'List view' : 'Grid view',
                        icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view),
                        onPressed: () => setState(() => _grid = !_grid),
                      ),
                      const DisguiseMenu(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: widget.coach ? Pulse(child: searchBar) : searchBar,
                ),
                Expanded(
                  child: _notes.isEmpty
                      ? _Empty(color: scheme.onSurfaceVariant)
                      : notes.isEmpty
                          ? Center(
                              child: Text('No matching notes',
                                  style: TextStyle(color: scheme.onSurfaceVariant)))
                          : _NotesGrid(
                              notes: notes,
                              columns: _grid ? 2 : 1,
                              onOpen: _open,
                              onLongPress: _showOptions,
                            ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _create,
            tooltip: 'New note',
            child: const Icon(Icons.add, size: 30),
          ),
        );
      }),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 96, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Notes you add appear here',
              style: TextStyle(fontSize: 17, color: color)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.columns,
    required this.onOpen,
    required this.onLongPress,
  });

  final List<DisguiseNote> notes;
  final int columns;
  final void Function(DisguiseNote) onOpen;
  final void Function(DisguiseNote) onLongPress;

  @override
  Widget build(BuildContext context) {
    final pinned = notes.where((n) => n.isPinned).toList();
    final others = notes.where((n) => !n.isPinned).toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: muted)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        if (pinned.isNotEmpty) ...[
          label('Pinned'),
          _masonry(pinned),
          if (others.isNotEmpty) label('Others'),
        ],
        _masonry(others),
      ],
    );
  }

  Widget _masonry(List<DisguiseNote> list) {
    final cols = List.generate(columns, (_) => <DisguiseNote>[]);
    final heights = List.filled(columns, 0.0);
    for (final note in list) {
      var shortest = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[shortest]) shortest = i;
      }
      cols[shortest].add(note);
      heights[shortest] += 60 + note.content.length.clamp(0, 180) * 0.6;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final col in cols)
          Expanded(
            child: Column(
              children: [
                for (final note in col)
                  _NoteCard(
                    note: note,
                    onTap: () => onOpen(note),
                    onLongPress: () => onLongPress(note),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap, required this.onLongPress});

  final DisguiseNote note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final fill = note.colorFor(brightness);
    final plain = note.colorIndex == 0;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: plain ? scheme.surface : fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: plain
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty)
                  Text(note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (note.title.isNotEmpty && note.content.isNotEmpty)
                  const SizedBox(height: 6),
                if (note.content.isNotEmpty)
                  Text(note.content,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DisguiseNoteEditor extends StatefulWidget {
  const DisguiseNoteEditor({
    super.key,
    required this.note,
    this.isNew = false,
    required this.onSave,
    required this.onDelete,
  });

  final DisguiseNote note;
  final bool isNew;
  final void Function(DisguiseNote) onSave;
  final VoidCallback onDelete;

  @override
  State<DisguiseNoteEditor> createState() => _DisguiseNoteEditorState();
}

class _DisguiseNoteEditorState extends State<DisguiseNoteEditor> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _content = TextEditingController(text: widget.note.content);
  late int _colorIndex = widget.note.colorIndex;
  late bool _pinned = widget.note.isPinned;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) _title.addListener(_tryTitle);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _tryTitle() async {
    final text = _title.text;
    if (text.trim().length < 4 || _closing) return;
    if (await tryVaultCode(context, text) && mounted) {
      _closing = true;
      Navigator.of(context).pop();
    }
  }

  void _commit() {
    if (_closing) return;
    _closing = true;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty && content.isEmpty) {
      if (!widget.isNew) widget.onDelete();
      return;
    }
    final changed = title != widget.note.title ||
        content != widget.note.content ||
        _colorIndex != widget.note.colorIndex ||
        _pinned != widget.note.isPinned;
    if (!changed && !widget.isNew) return;
    widget.note
      ..title = title
      ..content = content
      ..colorIndex = _colorIndex
      ..isPinned = _pinned
      ..updatedAt = DateTime.now();
    widget.onSave(widget.note);
  }

  Future<void> _pickColor() async {
    final brightness = Theme.of(context).brightness;
    final colors = brightness == Brightness.dark
        ? DisguiseNote.darkColors
        : DisguiseNote.lightColors;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < colors.length; i++)
                InkResponse(
                  onTap: () => Navigator.pop(context, i),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: i == 0 ? null : colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _colorIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: i == _colorIndex ? 3 : 1,
                      ),
                    ),
                    child: i == 0 ? const Icon(Icons.format_color_reset_outlined) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _colorIndex = picked);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = brightness == Brightness.dark
        ? DisguiseNote.darkColors
        : DisguiseNote.lightColors;
    final fill = _colorIndex == 0 ? null : colors[_colorIndex % colors.length];

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commit();
      },
      child: Scaffold(
        backgroundColor: fill,
        appBar: AppBar(
          backgroundColor: fill,
          actions: [
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            IconButton(
              tooltip: 'Colour',
              icon: const Icon(Icons.palette_outlined),
              onPressed: _pickColor,
            ),
            if (!widget.isNew)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _closing = true;
                  widget.onDelete();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _content,
                  autofocus: widget.isNew,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 17, height: 1.45),
                  decoration: const InputDecoration(
                    hintText: 'Note',
                    border: InputBorder.none,
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
