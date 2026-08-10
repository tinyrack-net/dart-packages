/// Typed key used to register and resolve one common service.
final class ServiceIdentifier<T> {
  const ServiceIdentifier._(this.id);

  /// Stable xterm service identifier.
  final String id;

  @override
  String toString() => id;
}

/// Globally interned service identifiers, matching xterm decorator identity.
final Map<String, Object> serviceRegistry = <String, Object>{};

/// Returns the existing identifier for [id], or creates it once.
ServiceIdentifier<T> createServiceIdentifier<T>(String id) {
  final existing = serviceRegistry[id];
  if (existing != null) return existing as ServiceIdentifier<T>;
  final created = ServiceIdentifier<T>._(id);
  serviceRegistry[id] = created;
  return created;
}

/// One constructor parameter supplied by [InstantiationService].
final class ServiceDependency<T> {
  /// Creates dependency metadata at zero-based argument [index].
  const ServiceDependency({
    required this.id,
    required this.index,
    this.optional = false,
  });

  /// Service key.
  final ServiceIdentifier<T> id;

  /// Constructor argument position.
  final int index;

  /// Reserved parity flag; xterm's current registry always stores false.
  final bool optional;
}

/// Explicit Dart replacement for TypeScript decorator constructor metadata.
final class ServiceConstructor<T> {
  /// Creates a constructor adapter and its injected [dependencies].
  const ServiceConstructor({
    required this.name,
    required this.factory,
    this.dependencies = const <ServiceDependency<Object?>>[],
  });

  /// Constructor name used in parity errors.
  final String name;

  /// Creates an instance from static arguments followed by injected services.
  final T Function(List<Object?> arguments) factory;

  /// Service dependency metadata.
  final List<ServiceDependency<Object?>> dependencies;
}

/// Returns a constructor's dependencies in declaration order.
List<ServiceDependency<Object?>> getServiceDependencies<T>(
  ServiceConstructor<T> constructor,
) => List<ServiceDependency<Object?>>.of(constructor.dependencies);

/// Mutable typed service collection.
final class ServiceCollection {
  /// Creates a collection from optional key/value records.
  ServiceCollection([
    Iterable<(ServiceIdentifier<Object?>, Object?)> entries =
        const <(ServiceIdentifier<Object?>, Object?)>[],
  ]) {
    for (final (id, instance) in entries) {
      set<Object?>(id, instance);
    }
  }

  final Map<Object, Object?> _entries = <Object, Object?>{};

  /// Replaces [id] and returns its previous value.
  T? set<T>(ServiceIdentifier<T> id, T instance) {
    final previous = _entries[id];
    _entries[id] = instance;
    return previous as T?;
  }

  /// Visits entries in insertion order.
  void forEach(
    void Function(ServiceIdentifier<Object?> id, Object? instance) callback,
  ) {
    for (final entry in _entries.entries) {
      callback(entry.key as ServiceIdentifier<Object?>, entry.value);
    }
  }

  /// Whether [id] has a registered value.
  bool has(ServiceIdentifier<Object?> id) => _entries.containsKey(id);

  /// Returns the registered service, if any.
  T? get<T>(ServiceIdentifier<T> id) => _entries[id] as T?;
}

/// Identifier under which each instantiation service registers itself.
final ServiceIdentifier<InstantiationService> instantiationServiceIdentifier =
    createServiceIdentifier<InstantiationService>('instantiationService');

/// Resolves registered services and constructs explicit Dart adapters.
final class InstantiationService {
  /// Creates an empty service collection containing this service.
  InstantiationService() {
    _services.set(instantiationServiceIdentifier, this);
  }

  final ServiceCollection _services = ServiceCollection();

  /// Adds or replaces a service.
  void setService<T>(ServiceIdentifier<T> id, T instance) {
    _services.set(id, instance);
  }

  /// Gets a registered service.
  T? getService<T>(ServiceIdentifier<T> id) => _services.get(id);

  /// Creates an instance from static [arguments] and injected dependencies.
  T createInstance<T>(
    ServiceConstructor<T> constructor, [
    List<Object?> arguments = const <Object?>[],
  ]) {
    final dependencies = getServiceDependencies(constructor)
      ..sort((left, right) => left.index.compareTo(right.index));
    final serviceArguments = <Object?>[];
    for (final dependency in dependencies) {
      final service = _services.get<Object?>(dependency.id);
      if (service == null) {
        throw StateError(
          '[createInstance] ${constructor.name} depends on UNKNOWN service '
          '${dependency.id.id}.',
        );
      }
      serviceArguments.add(service);
    }
    final firstServicePosition = dependencies.isEmpty
        ? arguments.length
        : dependencies.first.index;
    if (arguments.length != firstServicePosition) {
      throw StateError(
        '[createInstance] First service dependency of ${constructor.name} at '
        'position ${firstServicePosition + 1} conflicts with '
        '${arguments.length} static arguments',
      );
    }
    return constructor.factory(<Object?>[...arguments, ...serviceArguments]);
  }
}
