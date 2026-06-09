import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 220,
      color: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com logo da loja
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: 52,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const Divider(color: AppColors.grey900, height: 1),
          const SizedBox(height: 12),

          // Itens de navegação
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: AppRoutes.dashboard,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Produtos',
            route: AppRoutes.products,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Clientes',
            route: AppRoutes.customers,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.point_of_sale_outlined,
            label: 'Vendas',
            route: AppRoutes.sales,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.assignment_return_outlined,
            label: 'Devoluções',
            route: AppRoutes.returns,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.discount_outlined,
            label: 'Cupons',
            route: AppRoutes.coupons,
            currentLocation: location,
          ),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Relatórios',
            route: AppRoutes.reports,
            currentLocation: location,
          ),

          // Somente admin vê o gerenciamento de usuários
          if (user?.isAdmin == true)
            _NavItem(
              icon: Icons.manage_accounts_outlined,
              label: 'Usuários',
              route: AppRoutes.users,
              currentLocation: location,
            ),

          const Spacer(),
          const Divider(color: AppColors.grey900, height: 1),

          // Rodapé com nome do usuário e botão de logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined,
                    color: AppColors.grey500, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user?.name ?? '',
                    style: const TextStyle(
                        color: AppColors.grey500, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.grey500,
                      size: 18),
                  tooltip: 'Sair',
                  onPressed: () => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentLocation == route;

    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.white.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive ? AppColors.white : AppColors.grey500,
                size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.white : AppColors.grey500,
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
