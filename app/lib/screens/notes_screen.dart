import 'package:flutter/material.dart';

import '../app.dart';
import 'home_screen.dart' show openWord;

/// Fenêtre de saisie de la note personnelle d'un mot.
Future<void> editNote(BuildContext context, String word) async {
  final user = AppScope.of(context).user;
  final controller = TextEditingController(text: user.noteFor(word) ?? '');
  final saved = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Note : $word'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Votre note personnelle…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        if (user.noteFor(word) != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Supprimer'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (saved != null) await user.setNote(word, saved);
}

/// Toutes les notes personnelles.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes notes')),
      body: ListenableBuilder(
        listenable: user,
        builder: (context, _) {
          final words = user.notes.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          if (words.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune note. Touchez l\'icône de note en bas de la fiche d\'un mot.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: words.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final word = words[i];
              return ListTile(
                title: Text(word),
                subtitle: Text(
                  user.noteFor(word) ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => openWord(context, word),
                trailing: IconButton(
                  tooltip: 'Modifier la note',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => editNote(context, word),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
