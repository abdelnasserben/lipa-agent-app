import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../activity/activity_screen.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../operations/operations_hub_screen.dart';
import '../profile/profile_screen.dart';

/// The agent app shell: a tab body and the 5-entry tab bar with the central
/// "Opérer" FAB. Mirrors the Lipa customer shell's structure (per-tab nav
/// stacks, re-tap-to-root, hardware-back handling) but with agent destinations.
class AgentShell extends ConsumerStatefulWidget {
  const AgentShell({super.key});

  @override
  ConsumerState<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends ConsumerState<AgentShell> {
  int _index = 0;

  // Each tab keeps its own navigation stack.
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _roots = [
    HomeScreen(),
    ActivityScreen(),
    OperationsHubScreen(),
    CardsScreen(),
    ProfileScreen(),
  ];

  void _select(int i) {
    if (i == _index) {
      // Re-tap pops the tab to its root.
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  Future<bool> _onWillPop() async {
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _roots.length; i++)
                Navigator(
                  key: _navKeys[i],
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (_) => _roots[i],
                    settings: settings,
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _TabBar(index: _index, onSelect: _select),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.grid_view_rounded, 'Accueil'),
    (Icons.list_alt, 'Activité'),
    (Icons.bolt_rounded, 'Opérer'),
    (Icons.credit_card_rounded, 'Cartes'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: i == 2
                      ? _Fab(
                          icon: _items[i].$1,
                          label: _items[i].$2,
                          onTap: () => onSelect(i),
                          active: index == i,
                        )
                      : _TabItem(
                          icon: _items[i].$1,
                          label: _items[i].$2,
                          active: index == i,
                          onTap: () => onSelect(i),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.inkHi : AppColors.inkLow;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(label,
              style: AppText.ui(
                  size: 11,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.active});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.fabGlow,
                      blurRadius: 18,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: Text(label,
                style: AppText.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: active ? AppColors.inkHi : AppColors.inkMid)),
          ),
        ],
      ),
    );
  }
}
