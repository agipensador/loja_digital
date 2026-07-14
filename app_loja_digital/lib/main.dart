import 'package:app_loja_digital/models/cart_manager.dart';
import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/orders_manager.dart';
import 'package:app_loja_digital/models/product_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
      initialRoute: '/base',
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
          case '/base':
          default:
            return MaterialPageRoute(builder: (_) => const BaseScreen());
        }
      },
    );
  }
}
