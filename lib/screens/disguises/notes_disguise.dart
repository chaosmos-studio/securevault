import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/providers/app_state.dart';

class Note {
  String id;
  String title;
  String content;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

class NotesDisguise extends StatefulWidget {
  const NotesDisguise({super.key});

  @override
  State<NotesDisguise> createState() => _NotesDisguiseState();
}

class _NotesDisguiseState extends State<NotesDisguise> {
  List<Note> _notes = [];
  int _secretTapCount = 0;
  DateTime? _lastTapTime;
  final _secretCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _secretCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('disguise_notes');
    if (notesJson != null) {
      final notesList = json.decode(notesJson) as List;
      setState(() {
        _notes = notesList.map((n) => Note.fromJson(n)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('disguise_notes', json.encode(_notes.map((n) => n.toJson()).toList()));
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 500) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          controller: _secretCodeController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter secret code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _tryUnlock(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _secretCodeController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _tryUnlock,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _tryUnlock() async {
    final code = _secretCodeController.text;
    _secretCodeController.clear();
    
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
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Note',
      content: '',
      updatedAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, note);
    });
    _saveNotes();
    _editNote(note);
  }

  void _editNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditor(
          note: note,
          onSave: (updatedNote) {
            setState(() {
              final index = _notes.indexWhere((n) => n.id == updatedNote.id);
              if (index != -1) {
                _notes[index] = updatedNote;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text('Notes'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNote,
          ),
        ],
      ),
      body: _notes.isEmpty
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
                  TextButton.icon(
                    onPressed: _createNote,
                    icon: const Icon(Icons.add),
                    label: const Text('Create a note'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return ListTile(
                  title: Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    note.content.isEmpty ? 'No content' : note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  onTap: () => _editNote(note),
                );
              },
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
}

class NoteEditor extends StatefulWidget {
  final Note note;
  final Function(Note) onSave;
  final VoidCallback onDelete;

  const NoteEditor({
    super.key,
    required this.note,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _save,
        ),
        actions: [
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Start typing...',
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
