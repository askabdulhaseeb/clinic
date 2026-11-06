import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late MockInventoryRepository repo;
  late StreamController<List<InventoryItem>> items;
  var subscriptions = 0;

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockInventoryRepository();
    items = StreamController<List<InventoryItem>>.broadcast(
      onListen: () => subscriptions++,
    );
    subscriptions = 0;
    when(repo.watchItems).thenAnswer((_) => items.stream);
  });
  tearDown(() async {
    await items.close();
    await auth.dispose();
  });

  test('listens for reception and admin sessions, not doctor-only', () async {
    final rec = InventoryController(
      repository: repo,
      session: await signedInSession(auth, receptionUser),
    );
    expect(rec.listening, isTrue);
    rec.dispose();

    final adm = InventoryController(
      repository: repo,
      session: await signedInSession(auth, adminUser),
    );
    expect(adm.listening, isTrue);
    adm.dispose();

    final doc = InventoryController(
      repository: repo,
      session: await signedInSession(auth, doctorUser),
    );
    expect(doc.listening, isFalse);
    doc.dispose();
    expect(subscriptions, 2);
  });

  test(
    'exposes items by category, lens cells and the low-stock list',
    () async {
      final ctrl = InventoryController(
        repository: repo,
        session: await signedInSession(auth, adminUser),
      );
      expect(ctrl.loading, isTrue);
      final lens = sampleLensItem(stock: 1);
      items.add([
        sampleItem(),
        sampleItem(id: 'item-low', name: 'Belladonna', stock: 2),
        sampleItem(id: 'item-frame', category: ItemCategory.frame, name: 'Ray'),
        sampleItem(id: 'item-off', name: 'Old', stock: 0, active: false),
        lens,
      ]);
      await pumpEventQueue();

      expect(ctrl.loading, isFalse);
      expect(ctrl.items, hasLength(5));
      expect(ctrl.byCategory(ItemCategory.medicine).map((i) => i.id), [
        'item-arnica',
        'item-low',
        'item-off',
      ]);
      expect(ctrl.byId('item-frame')?.name, 'Ray');
      expect(ctrl.byId('nope'), isNull);
      expect(
        ctrl.lensItem(
          const LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5),
        ),
        lens,
      );
      expect(
        ctrl.lensItem(
          const LensPower(type: LensType.bifocal, sph: -1.25, cyl: -0.5),
        ),
        isNull,
      );
      // Active items at or below their threshold, lenses included.
      expect(ctrl.lowStock.map((i) => i.id), ['item-low', lens.id]);
      ctrl.dispose();
    },
  );

  test('clears and stops on sign-out, surfaces stream errors', () async {
    final session = await signedInSession(auth, adminUser);
    final ctrl = InventoryController(repository: repo, session: session);
    items.add([sampleItem()]);
    await pumpEventQueue();
    expect(ctrl.items, hasLength(1));

    items.addError(Exception('boom'));
    await pumpEventQueue();
    expect(ctrl.error, isNotNull);

    auth.emitUid(null);
    await pumpEventQueue();
    expect(ctrl.listening, isFalse);
    expect(ctrl.items, isEmpty);
    expect(ctrl.error, isNull);
    ctrl.dispose();
  });
}
