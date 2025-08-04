## [1.0.0] - 2025-08-04

### Added
- **Arity Enum:** Introduced `Arity` enum to explicitly specify function arity for signal callbacks and once handlers.
    - Added `VarArgs` value for use with `emitUntyped` and signals that expect a variable number of arguments.
- **dispose() Method:** Added `dispose()` to clean up emitter state and release memory resources.

### Changed
- **Memory Management:** Signals map is now lazily instantiated, reducing GC pressure and improving memory usage for lightweight objects.
- **Improved `once` Handler:** Major enhancements to `once()` usage—now requires explicit arity to ensure correct parameter passing and cross-target compatibility.
- **Untyped Once Handling:** `once` now properly supports untyped emits, allowing one-time handlers for variadic argument signals.

### Fixed
- **Callback Removal:** Signals are now reliably removed when their last callback is unregistered, preventing lingering empty signal entries.
- **Callback Skipping:** Fixed an issue where certain callbacks could be skipped when emitting signals.
- **HashLink & Neko Compatibility:** Addressed `once` handler issues on HashLink and Neko targets, ensuring stable cross-platform behavior.
- **Documentation:** Corrected documentation for `once()` to properly reflect its usage and signature.

### Breaking
- **Explicit Arity Required:** Using `once()` now requires specifying the callback arity via the new `Arity` enum. This may break existing code that relied on the old signature.
- **Internal API Changes:** Some internal behaviors (such as lazy map instantiation and dispose logic) may require consumers to adjust code that interacts closely with Emitter internals.
