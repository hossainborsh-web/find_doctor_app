import 'package:flutter/foundation.dart';

import '../account_service.dart';
import '../connect_service.dart';
import '../hr_service.dart';
import '../inventory_service.dart';
import '../post_service.dart';

/// Starts each service's live cloud sync for whoever is signed in, and
/// restarts it when their role or hospital changes (e.g. after HR hires
/// them), so they see exactly what their role allows.
class CloudSession {
  CloudSession._();

  static String? _key;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    AccountService.instance.addListener(_check);
    _check();
  }

  static void _check() {
    final me = AccountService.instance.currentAccount;
    final key = me == null
        ? null
        : [
            me.id,
            me.email,
            me.role.name,
            me.doctorKind?.name,
            me.managerLevel?.name,
            me.hospital,
            me.status.name,
          ].join('|');
    if (key == _key) return;
    _key = key;
    if (me == null) {
      ConnectService.instance.detach();
      HrService.instance.detach();
      InventoryService().detach();
      PostService.instance.detach();
      return;
    }
    debugPrint('Find Doctor: syncing as ${me.email} (${me.typeLabel})');
    ConnectService.instance.attach(me);
    HrService.instance.attach(me);
    InventoryService().attach(me);
    PostService.instance.attach(me);
  }
}
