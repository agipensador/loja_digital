import 'package:app_loja_digital/screens/chat/chat_screen.dart';
import 'package:app_loja_digital/models/campaign.dart';
import 'package:app_loja_digital/screens/start_store/start_store_screen.dart';
import 'package:app_loja_digital/screens/notifications/compose_campaign_screen.dart';
import 'package:app_loja_digital/screens/notifications/notifications_screen.dart';
import 'package:intl/intl.dart';
import 'package:app_loja_digital/l10n/app_localizations.dart';
import 'package:app_loja_digital/screens/import_catalog/import_catalog_screen.dart';
import 'package:app_loja_digital/common/store_gate.dart';
import 'package:app_loja_digital/models/usage_manager.dart';
import 'package:app_loja_digital/services/usage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:app_loja_digital/models/supplier.dart';
import 'package:app_loja_digital/screens/suppliers/restock_screen.dart';
import 'package:app_loja_digital/screens/suppliers/suppliers_screen.dart';
import 'package:app_loja_digital/models/a2_publish_manager.dart';
import 'package:app_loja_digital/models/address_manager.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/delivery_zones_manager.dart';
import 'package:app_loja_digital/screens/addresses/addresses_screen.dart';
import 'package:app_loja_digital/screens/delivery_zones/delivery_zones_screen.dart';
import 'package:app_loja_digital/models/favorites_manager.dart';
import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/screens/a2_publish/a2_publish_screen.dart';
import 'package:app_loja_digital/screens/appearance/appearance_screen.dart';
import 'package:app_loja_digital/screens/stock/stock_panel_screen.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/payment_manager.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:app_loja_digital/screens/payment_methods/add_card_screen.dart';
import 'package:app_loja_digital/screens/payment_methods/payment_methods_screen.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/tenant_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/screens/subscription/subscription_screen.dart';
import 'package:app_loja_digital/screens/team/team_screen.dart';
import 'package:app_loja_digital/screens/edit_store/edit_store_screen.dart';
import 'package:app_loja_digital/screens/favorites/favorites_screen.dart';
import 'package:app_loja_digital/screens/profile/profile_screen.dart';
import 'package:app_loja_digital/screens/base/base_screen.dart';
import 'package:app_loja_digital/screens/login/login_screen.dart';
import 'package:app_loja_digital/screens/signup/signup_screen.dart';
import 'package:app_loja_digital/screens/cart/cart_screen.dart';
import 'package:app_loja_digital/screens/address/address_screen.dart';
import 'package:app_loja_digital/screens/checkout/checkout_screen.dart';
import 'package:app_loja_digital/models/product.dart';
import 'package:app_loja_digital/screens/product/product_screen.dart';
import 'package:app_loja_digital/screens/edit_product/edit_product_screen.dart';
import 'package:app_loja_digital/screens/legal/legal_screen.dart';
import 'package:app_loja_digital/screens/mp_connect/mp_connect_screen.dart';
import 'package:app_loja_digital/screens/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_loja_digital/models/page_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cache local do Firestore também na web (no mobile já vem ligado): é o
  // que permite a sincronização incremental do catálogo.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );

  // Teste local sem tocar no Firebase real:
  // firebase emulators:start  +  flutter run --dart-define=USE_EMULATORS=true
  const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  if (useEmulators) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await fb.FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }

  // E-mails do Firebase (confirmar e-mail, trocar senha) em português.
  await fb.FirebaseAuth.instance.setLanguageCode('pt-BR');

  // Conta a visita (medidor do plano) sem atrasar a abertura.
  Intl.defaultLocale = 'pt_BR';
  UsageService.recordVisit();

  runApp(
    MultiProvider(
      providers: [
        // PageController
        ListenableProvider<PageController>(
          create: (_) => PageController(),
        ),

        // PageManager depende do PageController (pega o PageController acima)
        ChangeNotifierProvider<PageManager>(
          create: (context) => PageManager(context.read<PageController>()),
        ),

        // ThemeManager (aparência personalizável)
        ChangeNotifierProvider<ThemeManager>(
          create: (_) => ThemeManager(),
          lazy: false,
        ),

        // UserManager
        ChangeNotifierProvider<UserManager>(
          create: (_) => UserManager(),
          lazy: false,
        ),

        // TenantManager: a CONTA da loja atual (equipe, plano, assinatura).
        ChangeNotifierProxyProvider<UserManager, TenantManager>(
          create: (_) => TenantManager(FakePaymentService()),
          update: (_, userManager, tenantManager) =>
              tenantManager!..updateUser(userManager),
          lazy: false,
        ),

        // ProductManager
        ChangeNotifierProvider<ProductManager>(
          create: (_) => ProductManager(),
          lazy: false,
        ),

        // HomeManager (seções editáveis da tela inicial)
        ChangeNotifierProvider<HomeManager>(
          create: (_) => HomeManager(),
          lazy: false,
        ),

        // StoresManager (lojas)
        ChangeNotifierProvider<StoresManager>(
          create: (_) => StoresManager(),
          lazy: false,
        ),

        // A2PublishManager (publicar produtos no app A2 — só admin usa)
        ChangeNotifierProvider<A2PublishManager>(
          create: (_) => A2PublishManager(),
        ),

        // DeliveryZonesManager (zonas de entrega própria por bairro/dia)
        ChangeNotifierProvider<DeliveryZonesManager>(
          create: (_) => DeliveryZonesManager(),
        ),

        // Fornecedores (pedido de reposição pelo WhatsApp)
        ChangeNotifierProvider<SuppliersManager>(
          create: (_) => SuppliersManager(),
        ),

        // CartManager depende do UserManager -> ProxyProvider
        ChangeNotifierProxyProvider<UserManager, CartManager>(
          create: (_) => CartManager(),
          update: (_, userManager, cartManager) =>
              cartManager!..updateUser(userManager),
          lazy: false,
        ),

        // Uso do mês (visitas/fotos) — medidor do plano, só para a equipe
        ChangeNotifierProxyProvider<UserManager, UsageManager>(
          create: (_) => UsageManager(),
          update: (_, userManager, usage) => usage!..updateUser(userManager),
        ),

        // OrdersManager depende do UserManager
        ChangeNotifierProxyProvider<UserManager, OrdersManager>(
          create: (_) => OrdersManager(),
          update: (_, userManager, ordersManager) =>
              ordersManager!..updateUser(userManager),
          lazy: false,
        ),

        // FavoritesManager depende do UserManager
        ChangeNotifierProxyProvider<UserManager, FavoritesManager>(
          create: (_) => FavoritesManager(),
          update: (_, userManager, favoritesManager) =>
              favoritesManager!..updateUser(userManager),
          lazy: false,
        ),

        // AddressManager depende do UserManager (endereços salvos)
        ChangeNotifierProxyProvider<UserManager, AddressManager>(
          create: (_) => AddressManager(),
          update: (_, userManager, addressManager) =>
              addressManager!..updateUser(userManager),
          lazy: false,
        ),

        // PaymentManager depende do UserManager.
        // Troque FakePaymentService por MercadoPagoService ao integrar o MP.
        ChangeNotifierProxyProvider<UserManager, PaymentManager>(
          create: (_) => PaymentManager(FakePaymentService()),
          update: (_, userManager, paymentManager) =>
              paymentManager!..updateUser(userManager),
          lazy: false,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: theme.storeName,
      theme: ThemeData(
        primaryColor: theme.primary,
        scaffoldBackgroundColor: theme.background,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          foregroundColor: theme.primary,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // '/base' como initialRoute fazia o Flutter empilhar '/' E '/base'
      // (duas BaseScreen com o mesmo PageController -> troca de telas quebrava).
      navigatorKey: _navigatorKey,
      // i18n: pt-BR é o padrão; novos idiomas entram em lib/l10n/app_*.arb.
      locale: const Locale('pt'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Loja suspensa: cliente vê "fora do ar"; equipe entra para pagar.
      builder: (context, child) =>
          StoreGate(navigatorKey: _navigatorKey, child: child!),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => SignupScreen());
          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartScreen());
          case '/address':
            return MaterialPageRoute(builder: (_) => const AddressScreen());
          case '/checkout':
            return MaterialPageRoute(builder: (_) => const CheckoutScreen());
          case '/product':
            return MaterialPageRoute(
              builder: (_) => ProductScreen(settings.arguments as Product),
            );
          case '/edit_product':
            return MaterialPageRoute(
              builder: (_) =>
                  EditProductScreen(settings.arguments as Product?),
            );
          case '/edit_store':
            return MaterialPageRoute(
              builder: (_) => EditStoreScreen(settings.arguments as Store?),
            );
          case '/favorites':
            return MaterialPageRoute(
              builder: (_) => const FavoritesScreen(),
            );
          case '/profile':
            return MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            );
          case '/addresses':
            return MaterialPageRoute(
              builder: (_) => const AddressesScreen(),
            );
          case '/a2_publish':
            return MaterialPageRoute(
              builder: (_) => const A2PublishScreen(),
            );
          case '/stock':
            return MaterialPageRoute(
              builder: (_) => StockPanelScreen(
                  initialLocationId: settings.arguments as String?),
            );
          case '/notifications':
            return MaterialPageRoute(
              builder: (_) => const NotificationsScreen(),
            );
          case '/compose_campaign':
            return MaterialPageRoute(
              builder: (_) =>
                  ComposeCampaignScreen(draft: settings.arguments as Campaign?),
            );
          case '/chat':
            return MaterialPageRoute(
              builder: (_) => const ChatScreen(),
            );
          case '/start_store':
            return MaterialPageRoute(
              builder: (_) =>
                  StartStoreScreen(planId: settings.arguments as String?),
            );
          case '/import_catalog':
            return MaterialPageRoute(
              builder: (_) => const ImportCatalogScreen(),
            );
          case '/suppliers':
            return MaterialPageRoute(
              builder: (_) => const SuppliersScreen(),
            );
          case '/restock':
            return MaterialPageRoute(
              builder: (_) => RestockScreen(settings.arguments! as String),
            );
          case '/appearance':
            return MaterialPageRoute(
              builder: (_) => const AppearanceScreen(),
            );
          case '/payment_methods':
            return MaterialPageRoute(
              builder: (_) => const PaymentMethodsScreen(),
            );
          case '/add_card':
            return MaterialPageRoute(
              builder: (_) => const AddCardScreen(),
            );
          case '/subscription':
            return MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            );
          case '/team':
            return MaterialPageRoute(
              builder: (_) => const TeamScreen(),
            );
          case '/terms':
            return MaterialPageRoute(
              builder: (_) => const LegalScreen(LegalDocument.terms),
            );
          case '/privacy':
            return MaterialPageRoute(
              builder: (_) => const LegalScreen(LegalDocument.privacy),
            );
          case '/store_terms':
            return MaterialPageRoute(
              builder: (_) => const LegalScreen(LegalDocument.storeTerms),
            );
          case '/delivery_zones':
            return MaterialPageRoute(
              builder: (_) => const DeliveryZonesScreen(),
            );
          case '/reports':
            return MaterialPageRoute(
              builder: (_) => const ReportsScreen(),
            );
          case '/mp_connect':
            return MaterialPageRoute(
              builder: (_) => const MpConnectScreen(),
            );
          case '/base':
          default:
            return MaterialPageRoute(builder: (_) => const BaseScreen());
        }
      },
    );
  }
}
