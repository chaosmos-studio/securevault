import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';

class VaultNote {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  int colorIndex;
  bool isPinned;

  VaultNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.colorIndex = 0,
    this.isPinned = false,
  });

  static const List<Color> noteColors = [
    Colors.transparent,
    Color(0xFFf28b82),
    Color(0xFFfbbc04),
    Color(0xFFfff475),
    Color(0xFFccff90),
    Color(0xFFa7ffeb),
    Color(0xFFcbf0f8),
    Color(0xFFaecbfa),
    Color(0xFFd7aefb),
    Color(0xFFfdcfe8),
    Color(0xFFe6c9a8),
    Color(0xFFe8eaed),
  ];

  Color get color => noteColors[colorIndex % noteColors.length];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'colorIndex': colorIndex,
    'isPinned': isPinned,
  };

  factory VaultNote.fromJson(Map<String, dynamic> json) => VaultNote(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
    colorIndex: json['colorIndex'] ?? 0,
    isPinned: json['isPinned'] ?? false,
  );
}

class NotesVaultScreen extends StatefulWidget {
  const NotesVaultScreen({super.key});

  @override
  State<NotesVaultScreen> createState() => _NotesVaultScreenState();
}

class _NotesVaultScreenState extends State<NotesVaultScreen> {
  List<VaultNote> _notes = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultNote> get _filteredNotes {
    var notes = _notes.where((note) {
      if (_searchQuery.isEmpty) return true;
      return note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  Future<void> _loadNotes() async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    final noteItems = vault.items
        .where((item) => item.type == VaultItemType.note)
        .toList();
    final notes = <VaultNote>[];

    for (final item in noteItems) {
      final data = await VaultService.getItemData(vault, password, item.id);
      if (data != null) {
        try {
          final noteJson = json.decode(String.fromCharCodes(data));
          notes.add(VaultNote.fromJson(noteJson));
        } catch (e) {
          // Skip invalid notes
        }
      }
    }

    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _createNote() async {
    final note = VaultNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Note',
      content: '',
      updatedAt: DateTime.now(),
    );

    await _saveNote(note, isNew: true);
    if (mounted) {
      _editNote(note);
    }
  }

  Future<void> _saveNote(VaultNote note, {bool isNew = false}) async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    final noteData = utf8.encode(json.encode(note.toJson()));

    if (isNew) {
      await VaultService.addItem(
        vault: vault,
        password: password,
        type: VaultItemType.note,
        name: note.id,
        data: noteData,
      );
      await appState.refreshVault();
      setState(() {
        _notes.insert(0, note);
      });
    } else {
      final item = vault.items.firstWhere(
        (i) => i.type == VaultItemType.note && i.name == note.id,
        orElse: () => throw Exception('Note not found'),
      );

      await VaultService.deleteItem(vault, password, item.id);
      await appState.refreshVault();

      await VaultService.addItem(
        vault: appState.currentVault!,
        password: password,
        type: VaultItemType.note,
        name: note.id,
        data: noteData,
      );
      await appState.refreshVault();

      setState(() {
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = note;
        }
      });
    }
  }

  Future<void> _deleteNote(VaultNote note) async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    final item = vault.items.firstWhere(
      (i) => i.type == VaultItemType.note && i.name == note.id,
      orElse: () => throw Exception('Note not found'),
    );

    await VaultService.deleteItem(vault, password, item.id);
    await appState.refreshVault();

    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
    });
  }

  void _editNote(VaultNote note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VaultNoteEditor(
          note: note,
          onSave: (updatedNote) => _saveNote(updatedNote),
          onDelete: () => _deleteNote(note),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No secure notes yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _createNote,
              icon: const Icon(Icons.add),
              label: const Text('Create Note'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No notes yet' : 'No notes found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : _isGridView
                ? _buildGridView()
                : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGridView() {
    final pinnedNotes = _filteredNotes.where((n) => n.isPinned).toList();
    final otherNotes = _filteredNotes.where((n) => !n.isPinned).toList();

    return CustomScrollView(
      slivers: [
        if (pinnedNotes.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'PINNED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildNoteCard(pinnedNotes[index]),
                childCount: pinnedNotes.length,
              ),
            ),
          ),
        ],
        if (otherNotes.isNotEmpty && pinnedNotes.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'OTHERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildNoteCard(otherNotes[index]),
              childCount: otherNotes.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _buildNoteListTile(note);
      },
    );
  }

  Widget _buildNoteCard(VaultNote note) {
    return GestureDetector(
      onTap: () => _editNote(note),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        decoration: BoxDecoration(
          color: note.colorIndex == 0
              ? Theme.of(context).colorScheme.surfaceContainer
              : note.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: note.colorIndex == 0 ? null : Colors.black87,
                    ),
                  ),
                ),
                if (note.isPinned)
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: note.colorIndex == 0 ? Colors.grey : Colors.black54,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content.isEmpty ? 'No content' : note.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: note.colorIndex == 0
                      ? Colors.grey[600]
                      : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: note.colorIndex == 0 ? Colors.grey[500] : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListTile(VaultNote note) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: note.colorIndex == 0 ? null : note.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: () => _editNote(note),
        onLongPress: () => _showNoteOptions(note),
        leading: note.isPinned ? const Icon(Icons.push_pin, size: 18) : null,
        title: Text(
          note.title.isEmpty ? 'Untitled' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: note.colorIndex == 0 ? null : Colors.black87),
        ),
        subtitle: Text(
          note.content.isEmpty ? 'No content' : note.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: note.colorIndex == 0 ? Colors.grey[600] : Colors.black54,
          ),
        ),
        trailing: Text(
          _formatDate(note.updatedAt),
          style: TextStyle(
            color: note.colorIndex == 0 ? Colors.grey[500] : Colors.black45,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showNoteOptions(VaultNote note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                note.isPinned = !note.isPinned;
                _saveNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Change color'),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(VaultNote note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose color',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(VaultNote.noteColors.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      note.colorIndex = index;
                      _saveNote(note);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: VaultNote.noteColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: note.colorIndex == index
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.3),
                          width: note.colorIndex == index ? 3 : 1,
                        ),
                      ),
                      child: index == 0
                          ? const Icon(
                              Icons.format_color_reset,
                              color: Colors.grey,
                            )
                          : note.colorIndex == index
                          ? const Icon(Icons.check, color: Colors.black54)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(VaultNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }
}

class VaultNoteEditor extends StatefulWidget {
  final VaultNote note;
  final Function(VaultNote) onSave;
  final VoidCallback onDelete;

  const VaultNoteEditor({
    super.key,
    required this.note,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<VaultNoteEditor> createState() => _VaultNoteEditorState();
}

class _VaultNoteEditorState extends State<VaultNoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    widget.note.title = _titleController.text;
    widget.note.content = _contentController.text;
    widget.note.updatedAt = DateTime.now();
    widget.onSave(widget.note);
    Navigator.pop(context);
  }

  void _togglePin() {
    setState(() {
      widget.note.isPinned = !widget.note.isPinned;
    });
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose color',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(VaultNote.noteColors.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        widget.note.colorIndex = index;
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: VaultNote.noteColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.note.colorIndex == index
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.3),
                          width: widget.note.colorIndex == index ? 3 : 1,
                        ),
                      ),
                      child: index == 0
                          ? const Icon(
                              Icons.format_color_reset,
                              color: Colors.grey,
                            )
                          : widget.note.colorIndex == index
                          ? const Icon(Icons.check, color: Colors.black54)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.note.colorIndex == 0 ? null : widget.note.color;
    final textColor = widget.note.colorIndex == 0 ? null : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _save,
        ),
        title: const Text('Secure Note'),
        actions: [
          IconButton(
            icon: Icon(
              widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: _togglePin,
            tooltip: widget.note.isPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showColorPicker,
            tooltip: 'Change color',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(
                  color: widget.note.colorIndex == 0 ? null : Colors.black45,
                ),
                border: InputBorder.none,
              ),
            ),
            Divider(color: widget.note.colorIndex == 0 ? null : Colors.black26),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Start typing...',
                  hintStyle: TextStyle(
                    color: widget.note.colorIndex == 0 ? null : Colors.black45,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
