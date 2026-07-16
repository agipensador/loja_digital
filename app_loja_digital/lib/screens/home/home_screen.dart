import 'package:app_loja_digital/common/custom_drawer/custom_drawer.dart';
import 'package:app_loja_digital/models/home_manager.dart';
import 'package:app_loja_digital/models/theme_manager.dart';
import 'package:app_loja_digital/models/user_manager.dart';
import 'package:app_loja_digital/screens/home/components/add_section_widget.dart';
import 'package:app_loja_digital/screens/home/components/section_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      backgroundColor: context.watch<ThemeManager>().background,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            snap: true,
            floating: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: Consumer2<HomeManager, ThemeManager>(
              builder: (_, homeManager, theme, __) {
                if (homeManager.editing) {
                  // Em edição, o admin pode alterar o título aqui mesmo.
                  return TextFormField(
                    initialValue: theme.storeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Título da loja',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onChanged: theme.setStoreName,
                  );
                }
                return Text(theme.storeName);
              },
            ),
            actions: <Widget>[
              Consumer2<UserManager, HomeManager>(
                builder: (_, userManager, homeManager, __) {
                  if (!userManager.adminEnabled) {
                    return const SizedBox.shrink();
                  }
                  if (homeManager.editing) {
                    return Row(
                      children: <Widget>[
                        if (homeManager.loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          )
                        else ...[
                          TextButton(
                            onPressed: () {
                              homeManager.discardEditing();
                              context.read<ThemeManager>().discard();
                            },
                            child: const Text('Descartar',
                                style: TextStyle(color: Colors.white)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await context.read<ThemeManager>().save();
                              await homeManager.saveEditing();
                              if (context.mounted &&
                                  homeManager.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(homeManager.error!),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('Salvar',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: homeManager.enterEditing,
                  );
                },
              ),
              // Carrinho some no modo de edição.
              Consumer<HomeManager>(
                builder: (_, homeManager, __) {
                  if (homeManager.editing) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () => Navigator.of(context).pushNamed('/cart'),
                  );
                },
              ),
            ],
          ),
          Consumer<HomeManager>(
            builder: (_, homeManager, __) {
              final List<Widget> children = homeManager.sections
                  .map<Widget>((section) => SectionWidget(section))
                  .toList();

              if (homeManager.editing) {
                children.add(const AddSectionWidget());
              }

              // Em telas grandes (web), centraliza o conteúdo num limite de
              // largura para as imagens não ficarem gigantes.
              return SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
