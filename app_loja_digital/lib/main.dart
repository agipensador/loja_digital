import 'package:app_loja_digital/models/a2_publish_manager.dart';
import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/favorites_manager.dart';
import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/screens/a2_publish/a2_publish_screen.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/payment_manager.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/services/payment_service.dart';
import 'package:app_loja_digital/screens/payment_methods/add_card_screen.dart';
import 'package:app_loja_digital/screens/payment_methods/payment_methods_screen.dart';
import 'package:app_loja_digital/models/store.dart';
import 'package:app_loja_digital/models/stores_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
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

        // UserManager
        ChangeNotifierProvider<UserManager>(
          create: (_) => UserManager(),
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

        // CartManager depende do UserManager -> ProxyProvider
        ChangeNotifierProxyProvider<UserManager, CartManager>(
          create: (_) => CartManager(),
          update: (_, userManager, cartManager) =>
              cartManager!..updateUser(userManager),
          lazy: false,
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Loja da JU',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 4, 125, 141),
        scaffoldBackgroundColor: const Color.fromARGB(255, 4, 125, 141),
        appBarTheme: const AppBarTheme(elevation: 0),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // '/base' como initialRoute fazia o Flutter empilhar '/' E '/base'
      // (duas BaseScreen com o mesmo PageController -> troca de telas quebrava).
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
          case '/a2_publish':
            return MaterialPageRoute(
              builder: (_) => const A2PublishScreen(),
            );
          case '/payment_methods':
            return MaterialPageRoute(
              builder: (_) => const PaymentMethodsScreen(),
            );
          case '/add_card':
            return MaterialPageRoute(
              builder: (_) => const AddCardScreen(),
            );
          case '/base':
          default:
            return MaterialPageRoute(builder: (_) => const BaseScreen());
        }
      },
    );
  }
}
