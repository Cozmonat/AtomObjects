// Copyright (c) 2023 Natan Zalkin — MIT License

/// Type-safe key for storing and retrieving nested roots in an ``AtomRoot``.
///
/// Works the same way as ``AtomObjectKey`` but for nested ``AtomRoot`` instances.
/// When a child root is created lazily, its ``AtomRoot/parent`` is automatically
/// set to the owning parent root.
///
/// ```swift
/// struct ChildRootKey: AtomRootKey {
///     // Computed, not stored: each parent root gets its own child on
///     // first access (cached in that parent's RootStorage). A stored
///     // static would create one shared instance across ALL parents,
///     // whose `parent` reference gets reassigned on every access.
///     static var defaultRoot: AtomObjects { AtomObjects() }
/// }
///
/// let child = root[ChildRootKey.self] as AtomObjects
/// ```
public protocol AtomRootKey {

    /// The root type associated with this key.
    associatedtype Root: AtomRoot

    /// The default root instance used when the nested root is lazily created.
    static var defaultRoot: Root { get }
}
