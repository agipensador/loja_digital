import 'package:app_loja_digital/core/tenant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Permissões que o dono liga/desliga por funcionário. O nome do enum é a
/// chave gravada no Firestore e lida pelas rules — não renomear.
enum Perm {
  productsCreate,
  productsEdit,
  productsDelete,
  stock,
  orders,
  home,
  appearance,
  deliveryZones,
  locations,
  notifications,
}

extension PermLabel on Perm {
  String get label {
    switch (this) {
      case Perm.productsCreate:
        return 'Adicionar produtos';
      case Perm.productsEdit:
        return 'Editar produtos existentes';
      case Perm.productsDelete:
        return 'Excluir produtos';
      case Perm.stock:
        return 'Ajustar estoque';
      case Perm.orders:
        return 'Gerenciar pedidos';
      case Perm.home:
        return 'Editar a tela inicial';
      case Perm.appearance:
        return 'Alterar aparência (cores e nome)';
      case Perm.deliveryZones:
        return 'Zonas de entrega';
      case Perm.locations:
        return 'Editar dados das unidades';
      case Perm.notifications:
        return 'Enviar notificações aos clientes';
    }
  }
}

/// Gerente e funcionário têm o MESMO sistema de permissões (toggles); o
/// papel muda só o padrão inicial e como aparece na equipe. Nenhum dos dois
/// mexe no dono (garantido pelas rules: staff não escreve stores/{id}).
enum StaffRole { manager, employee }

extension StaffRoleLabel on StaffRole {
  String get label => this == StaffRole.manager ? 'Gerente' : 'Funcionário';

  Set<Perm> get defaultPerms => this == StaffRole.manager
      ? Perm.values.toSet()
      : StaffMember.defaultPerms;
}

/// Gerente ou funcionário da loja: stores/{storeId}/staff/{uid}.
class StaffMember {
  StaffMember({
    required this.uid,
    this.name = '',
    this.email = '',
    this.role = StaffRole.employee,
    Set<Perm>? perms,
    List<String>? locationIds,
  })  : perms = perms ?? role.defaultPerms,
        locationIds = locationIds ?? [];

  factory StaffMember.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final permsMap = Map<String, dynamic>.from(data['perms'] as Map? ?? {});
    return StaffMember(
      uid: doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      role: data['role'] == 'manager' ? StaffRole.manager : StaffRole.employee,
      perms: {
        for (final p in Perm.values)
          if (permsMap[p.name] == true) p,
      },
      locationIds:
          List<String>.from(data['locationIds'] as List<dynamic>? ?? []),
    );
  }

  /// Padrão ao adicionar: pode cuidar de produtos e pedidos, sem excluir.
  static Set<Perm> get defaultPerms =>
      {Perm.productsCreate, Perm.productsEdit, Perm.stock, Perm.orders};

  final String uid;
  final String name;
  final String email;
  StaffRole role;
  Set<Perm> perms;

  /// Unidades em que trabalha. Vazio = todas.
  List<String> locationIds;

  bool can(Perm p) => perms.contains(p);

  bool worksAt(String locationId) =>
      locationIds.isEmpty || locationIds.contains(locationId);

  DocumentReference<Map<String, dynamic>> get ref =>
      Tenant.col('staff').doc(uid);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'perms': {for (final p in Perm.values) p.name: perms.contains(p)},
      'locationIds': locationIds,
    };
  }
}
