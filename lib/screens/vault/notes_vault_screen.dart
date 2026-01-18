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

  VaultNote({
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

  factory VaultNote.fromJson(Map<String, dynamic> json) => VaultNote(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
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

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    final noteItems = vault.items.where((item) => item.type == VaultItemType.note).toList();
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
      body: ListView.builder(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.add),
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
        title: const Text('Secure Note'),
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
