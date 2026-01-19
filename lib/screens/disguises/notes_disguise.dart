import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/providers/app_state.dart';
import '../../core/widgets/disguise_menu.dart';

class DisguiseNote {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  int colorIndex;
  bool isPinned;

  DisguiseNote({
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

  factory DisguiseNote.fromJson(Map<String, dynamic> json) => DisguiseNote(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
    colorIndex: json['colorIndex'] ?? 0,
    isPinned: json['isPinned'] ?? false,
  );
}

class NotesDisguise extends StatefulWidget {
  const NotesDisguise({super.key});

  @override
  State<NotesDisguise> createState() => _NotesDisguiseState();
}

class _NotesDisguiseState extends State<NotesDisguise> {
  List<DisguiseNote> _notes = [];
  bool _isGridView = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

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

  List<DisguiseNote> get _filteredNotes {
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
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('disguise_notes');
    if (notesJson != null) {
      final notesList = json.decode(notesJson) as List;
      setState(() {
        _notes = notesList.map((n) => DisguiseNote.fromJson(n)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'disguise_notes',
      json.encode(_notes.map((n) => n.toJson()).toList()),
    );
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      _secretTapCount++;
      if (_secretTapCount >= 5) {
        _showSecretDialog();
        _secretTapCount = 0;
      }
    } else {
      _secretTapCount = 1;
    }
    _lastTapTime = now;
  }

  void _showSecretDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter secret code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _tryUnlock(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _tryUnlock(controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _tryUnlock(String code) async {
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(code);

    if (mounted) {
      Navigator.pop(context);
      if (unlocked) {
        Navigator.of(context).pushReplacementNamed('/vault');
      }
    }
  }

  void _createNote() {
    final note = DisguiseNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      content: '',
      updatedAt: DateTime.now(),
    );
    _editNote(note, isNew: true);
  }

  void _editNote(DisguiseNote note, {bool isNew = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DisguiseNoteEditor(
          note: note,
          isNew: isNew,
          onSave: (updatedNote) {
            setState(() {
              final index = _notes.indexWhere((n) => n.id == updatedNote.id);
              if (index != -1) {
                _notes[index] = updatedNote;
              } else {
                _notes.insert(0, updatedNote);
              }
            });
            _saveNotes();
          },
          onDelete: () {
            setState(() {
              _notes.removeWhere((n) => n.id == note.id);
            });
            _saveNotes();
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text('Notes'),
        ),
        actions: const [
          DisguiseMenu(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No notes yet',
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
                  )
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Text(
                          'No notes found',
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
              child: Text('PINNED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
              child: Text('OTHERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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

  Widget _buildNoteCard(DisguiseNote note) {
    return GestureDetector(
      onTap: () => _editNote(note),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        decoration: BoxDecoration(
          color: note.colorIndex == 0
              ? Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.white
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
                  Icon(Icons.push_pin, size: 16, color: note.colorIndex == 0 ? Colors.grey : Colors.black54),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content.isEmpty ? 'No content' : note.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: note.colorIndex == 0 ? Colors.grey[600] : Colors.black54),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(fontSize: 12, color: note.colorIndex == 0 ? Colors.grey[500] : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListTile(DisguiseNote note) {
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
          style: TextStyle(color: note.colorIndex == 0 ? Colors.grey[600] : Colors.black54),
        ),
        trailing: Text(
          _formatDate(note.updatedAt),
          style: TextStyle(color: note.colorIndex == 0 ? Colors.grey[500] : Colors.black45, fontSize: 12),
        ),
      ),
    );
  }

  void _showNoteOptions(DisguiseNote note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  note.isPinned = !note.isPinned;
                });
                _saveNotes();
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

  void _showColorPicker(DisguiseNote note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(DisguiseNote.noteColors.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        note.colorIndex = index;
                      });
                      _saveNotes();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: DisguiseNote.noteColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: note.colorIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                          width: note.colorIndex == index ? 3 : 1,
                        ),
                      ),
                      child: index == 0
                          ? const Icon(Icons.format_color_reset, color: Colors.grey)
                          : note.colorIndex == index
                              ? const Icon(Icons.check, color: Colors.black54)
                              : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DisguiseNote note) {
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
              setState(() {
                _notes.removeWhere((n) => n.id == note.id);
              });
              _saveNotes();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class DisguiseNoteEditor extends StatefulWidget {
  final DisguiseNote note;
  final bool isNew;
  final Function(DisguiseNote) onSave;
  final VoidCallback onDelete;

  const DisguiseNoteEditor({
    super.key,
    required this.note,
    this.isNew = false,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<DisguiseNoteEditor> createState() => _DisguiseNoteEditorState();
}

class _DisguiseNoteEditorState extends State<DisguiseNoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _colorIndex;
  bool _hasAttemptedUnlock = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _colorIndex = widget.note.colorIndex;

    if (widget.isNew) {
      _titleController.addListener(_onTitleChanged);
    }
  }

  @override
  void dispose() {
    if (widget.isNew) {
      _titleController.removeListener(_onTitleChanged);
    }
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (!_hasAttemptedUnlock) {
      _tryUnlockWithTitle();
    }
  }

  Future<void> _tryUnlockWithTitle() async {
    final title = _titleController.text.trim();
    if (title.length >= 4) {
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(title);

      if (unlocked && mounted) {
        _hasAttemptedUnlock = true;
        Navigator.of(context).pushReplacementNamed('/vault');
      }
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && widget.isNew) {
      Navigator.pop(context);
      return;
    }

    widget.note.title = title.isEmpty ? 'Untitled' : title;
    widget.note.content = content;
    widget.note.updatedAt = DateTime.now();
    widget.note.colorIndex = _colorIndex;

    widget.onSave(widget.note);
    Navigator.pop(context);
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
              const Text('Choose color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(DisguiseNote.noteColors.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _colorIndex = index);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: DisguiseNote.noteColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                          width: _colorIndex == index ? 3 : 1,
                        ),
                      ),
                      child: index == 0
                          ? const Icon(Icons.format_color_reset, color: Colors.grey)
                          : _colorIndex == index
                              ? const Icon(Icons.check, color: Colors.black54)
                              : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
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
    final bgColor = _colorIndex == 0 ? null : DisguiseNote.noteColors[_colorIndex];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor ?? Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _colorIndex == 0 ? null : Colors.black87),
          onPressed: _save,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: _colorIndex == 0 ? null : Colors.black87),
            onPressed: _showColorPicker,
          ),
          if (!widget.isNew)
            IconButton(
              icon: Icon(Icons.delete_outline, color: _colorIndex == 0 ? null : Colors.black87),
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
                color: _colorIndex == 0 ? null : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: widget.isNew ? 'Enter title...' : 'Title',
                hintStyle: TextStyle(color: _colorIndex == 0 ? null : Colors.black45),
                border: InputBorder.none,
              ),
            ),
            Divider(color: _colorIndex == 0 ? null : Colors.black26),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: _colorIndex == 0 ? null : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Start typing...',
                  hintStyle: TextStyle(color: _colorIndex == 0 ? null : Colors.black45),
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
