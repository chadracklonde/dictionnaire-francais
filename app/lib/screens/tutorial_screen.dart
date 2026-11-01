import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../data/user_store.dart';

/// Tutoriel de présentation, affiché au premier lancement puis depuis les
/// Réglages (« Revoir le tutoriel »).
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.user});

  final UserStore user;

  /// Ouvre le tutoriel en plein écran ; il se marque comme vu à la fermeture.
  static Future<void> show(BuildContext context, UserStore user) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TutorialScreen(user: user),
    ));
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _Page {
  const _Page({
    required this.icon,
    required this.title,
    required this.text,
    this.tips = const [],
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String text;
  final List<String> tips;
  final List<String> chips;
}

const _pages = <_Page>[
  _Page(
    icon: Icons.menu_book_rounded,
    title: 'Bienvenue',
    text: 'Dictionnaire et Conjugaison réunit plus de 500 000 mots, leurs '
        'définitions et la conjugaison de plus de 35 000 verbes. Tout '
        'fonctionne sans Internet.',
    tips: [
      'Ce tutoriel dure moins d\'une minute.',
      'Vous pourrez le revoir dans les Réglages.',
    ],
  ),
  _Page(
    icon: Icons.search_rounded,
    title: 'Rechercher un mot',
    text: 'Tapez un mot dans la barre de recherche de l\'accueil, ou touchez '
        'la loupe en haut de n\'importe quel écran.',
    tips: [
      'Les accents ne sont pas obligatoires : « ecole » trouve « école ».',
      'Un mot conjugué ou accordé (« mangeons », « belles ») mène à son mot de base.',
      'Une faute ? L\'application propose « Vouliez-vous dire : … ».',
    ],
  ),
  _Page(
    icon: Icons.article_outlined,
    title: 'Lire une fiche',
    text: 'Chaque fiche donne la nature du mot, sa prononciation, ses '
        'définitions, ses exemples et ses mots liés.',
    tips: [
      'Touchez un mot dans une définition pour l\'ouvrir.',
      'Touchez « exemples » pour les afficher ou les masquer.',
      'Le haut-parleur lit le mot à voix haute ; les icônes permettent de copier, de partager ou d\'ajouter aux favoris.',
      'Les boutons de la rangée « Définitions, Synonymes… » sautent à la section voulue.',
    ],
  ),
  _Page(
    icon: Icons.table_chart_outlined,
    title: 'Conjuguer un verbe',
    text: 'Sur la fiche d\'un verbe, touchez « conjugaison » pour voir tous '
        'les modes et tous les temps, un onglet par mode.',
    tips: [
      'Depuis la recherche, tapez directement :',
    ],
    chips: ['conjuguer manger', 'conjugaison de se laver'],
  ),
  _Page(
    icon: Icons.sort_by_alpha_rounded,
    title: 'Explorer le dictionnaire',
    text: 'L\'accueil propose plusieurs façons de découvrir des mots.',
    tips: [
      'Le mot du jour change chaque jour.',
      'L\'index alphabétique parcourt tous les mots, de A à Z.',
      'La recherche par motif aide pour les mots croisés : « ? » remplace une lettre et « * » plusieurs, comme dans « a?r?n » ou « ma*ion ».',
      'Mot au hasard, pour apprendre sans chercher.',
    ],
  ),
  _Page(
    icon: Icons.star_rounded,
    title: 'Favoris, notes et révision',
    text: 'Gardez ce qui vous intéresse et retrouvez-le facilement.',
    tips: [
      'L\'étoile ajoute un mot à vos favoris ; la liste est dans l\'entête de l\'accueil.',
      'L\'icône de note (en bas de la fiche) ajoute votre propre remarque.',
      '« Réviser mes favoris » vous fait réviser vos mots comme avec des cartes.',
      '« Récemment consultés » ramène vos derniers mots, en bas de l\'accueil.',
    ],
  ),
  _Page(
    icon: Icons.tune_rounded,
    title: 'Réglages et sauvegarde',
    text: 'Dans les Réglages (engrenage de l\'accueil), adaptez l\'application '
        'à votre confort.',
    tips: [
      'Thème clair, sombre ou automatique, et taille du texte.',
      'Rappel : un mot du jour chaque jour, sur Android.',
      'Sauvegarde et restauration de vos favoris et de vos notes, utile pour changer de téléphone.',
    ],
  ),
];

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == _pages.length - 1;

  Future<void> _finish() async {
    await widget.user.setTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _finish();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Pas d'entête ici : icônes de la barre d'état sombres sur fond clair.
        value: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(_last ? 'Fermer' : 'Passer'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _PageView(page: _pages[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Row(
                  children: [
                    if (_index > 0)
                      TextButton(
                        onPressed: () => _controller.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut),
                        child: const Text('Précédent'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      child: Text(_last ? 'Commencer' : 'Suivant'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Icon(page.icon,
                size: 56, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Text(page.text,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          for (final tip in page.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(Icons.check_circle_outline,
                        size: 20, color: theme.colorScheme.secondary),
                  ),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          if (page.chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in page.chips) Chip(label: Text(c)),
              ],
            ),
        ],
      ),
    );
  }
}
