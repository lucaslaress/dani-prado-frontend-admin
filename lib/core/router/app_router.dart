import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../theme/app_theme.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/coupons/coupons_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/returns/returns_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/users/users_screen.dart';
import '../../shared/widgets/main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const customers = '/customers';
  static const sales = '/sales';
  static const returns = '/returns';
  static const coupons = '/coupons';
  static const reports = '/reports';
  static const users = '/users';
}

class AppRouter {
  AppRouter._();

  static GoRouter createRouter(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: auth,
      redirect: (context, state) {
        final isInitialized = auth.isInitialized;
        final isAuthenticated = auth.isAuthenticated;
        final location = state.matchedLocation;

        // Ainda verificando sessão — mantém na splash
        if (!isInitialized) {
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        }

        // Inicializado: sai da splash para o destino correto
        if (location == AppRoutes.splash) {
          return isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;
        }

        // Não autenticado tentando acessar rota protegida
        if (!isAuthenticated && location != AppRoutes.login) {
          return AppRoutes.login;
        }

        // Já autenticado tentando voltar para login
        if (isAuthenticated && location == AppRoutes.login) {
          return AppRoutes.dashboard;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const _SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: AppRoutes.products,
              builder: (context, state) => const ProductsScreen(),
            ),
            GoRoute(
              path: AppRoutes.customers,
              builder: (context, state) => const CustomersScreen(),
            ),
            GoRoute(
              path: AppRoutes.sales,
              builder: (context, state) => const SalesScreen(),
            ),
            GoRoute(
              path: AppRoutes.returns,
              builder: (context, state) => const ReturnsScreen(),
            ),
            GoRoute(
              path: AppRoutes.coupons,
              builder: (context, state) => const CouponsScreen(),
            ),
            GoRoute(
              path: AppRoutes.reports,
              builder: (context, state) => const ReportsScreen(),
            ),
            GoRoute(
              path: AppRoutes.users,
              builder: (context, state) => const UsersScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

// Tela de loading exibida enquanto o app verifica a sessão salva
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/images/logo.png'),
              height: 180,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
