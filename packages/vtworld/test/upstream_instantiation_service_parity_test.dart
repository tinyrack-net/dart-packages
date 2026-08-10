import 'package:test/test.dart';
import 'package:vtworld/src/core/instantiation_service.dart';

void main() {
  group('ServiceRegistry and InstantiationService', () {
    test(
      'interns identifiers and stores dependencies by constructor index',
      () {
        final first = createServiceIdentifier<String>('parity-string');
        final second = createServiceIdentifier<String>('parity-string');
        expect(second, same(first));
        final constructor = ServiceConstructor<(int, String)>(
          name: 'Pair',
          dependencies: <ServiceDependency<Object?>>[
            ServiceDependency<Object?>(id: first, index: 1),
          ],
          factory: (arguments) =>
              (arguments.first! as int, arguments.last! as String),
        );
        expect(getServiceDependencies(constructor).single.index, 1);
      },
    );

    test('sets, gets, replaces, and visits collection entries', () {
      final id = createServiceIdentifier<String>('collection-string');
      final collection = ServiceCollection();
      expect(collection.set(id, 'first'), isNull);
      expect(collection.set(id, 'second'), 'first');
      expect(collection.get(id), 'second');
      expect(collection.has(id), isTrue);
      final values = <Object?>[];
      collection.forEach((_, value) => values.add(value));
      expect(values, <Object?>['second']);
    });

    test('injects services after exact static argument positions', () {
      final id = createServiceIdentifier<String>('injected-string');
      final service = InstantiationService()..setService(id, 'injected');
      final constructor = ServiceConstructor<(int, String)>(
        name: 'Pair',
        dependencies: <ServiceDependency<Object?>>[
          ServiceDependency<Object?>(id: id, index: 1),
        ],
        factory: (arguments) =>
            (arguments.first! as int, arguments.last! as String),
      );
      expect(service.createInstance(constructor, <Object?>[7]), (
        7,
        'injected',
      ));
      expect(
        () => service.createInstance(constructor),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects unknown injected services with the identifier', () {
      final missing = createServiceIdentifier<String>('missing-string');
      final constructor = ServiceConstructor<String>(
        name: 'Consumer',
        dependencies: <ServiceDependency<Object?>>[
          ServiceDependency<Object?>(id: missing, index: 0),
        ],
        factory: (arguments) => arguments.single! as String,
      );
      expect(
        () => InstantiationService().createInstance(constructor),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('UNKNOWN service missing-string'),
          ),
        ),
      );
    });
  });
}
