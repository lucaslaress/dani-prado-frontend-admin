import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_provider.dart';
import 'core/constants.dart';
import 'core/http/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sales/pdv_cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const DaniPradoApp());
}

class DaniPradoApp extends StatelessWidget {
  const DaniPradoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PdvCartProvider()),
        ProxyProvider<AuthProvider, ApiClient>(
          update: (_, auth, _) => ApiClient(
            baseUrl: AppConstants.backendUrl,
            getToken: () => auth.token,
            onUnauthorized: () => auth.refreshSession(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.createRouter(context);
          return MaterialApp.router(
            title: 'Dani Prado',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            routerConfig: router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('pt', 'BR'),
            ],
          );
        },
      ),
    );
  }
}
