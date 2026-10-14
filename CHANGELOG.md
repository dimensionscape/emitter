## [2.0.0] - Unreleased

A redesign: one `Emitter` carries ActionScript-style events and typed signals on one dispatch core, made to be
extended by frameworks. The 1.x API is replaced, not kept alongside.

### Added
- **Events:** `Event` (type, target, current target, bubbling, stop and cancel, `reuse`, `clone`), `EventType<T>`
  typing a listener by its event, `IEmitter`, and `addEventListener`, `removeEventListener`, `hasEventListener`,
  `removeEventListeners` and `dispatchEvent` on `Emitter`.
- **Bubbling** through `getEventParent()`, asked only for an event that bubbles; `stopPropagation` and
  `stopImmediatePropagation`.
- **Priorities** on both lanes, highest first; `prepend` puts a listener first among its priority.
- **Duplicate policy:** an event listener added again is ignored, as in ActionScript; `allowDuplicates` keeps it
  instead. Signals keep duplicates.
- **`has(token, listener)`** asks whether one listener is there, for events and signals alike.
- **Hooks for frameworks:** `listenersChanged(type, present)` from every path that adds or removes,
  `dispatchContained` with `listenerThrew`, `dispatchLocal`, and a delegate target (`new Emitter(owner)`).
- **Tests** on hxcpp, the jvm, Node, eval, HashLink and Neko (`haxe test/all.hxml`), and a benchmark
  (`haxe bench/all.hxml`).

### Changed
- **Signals** are `Signal0` to `Signal5`, typed by their arguments only (`Signal1<Int>` for
  `SignalType1<Int->Void, Int>`). `emit` is inlined, allocates nothing, and returns whether anything listened.
- **`once`** takes no arity, and `off` cancels it before it runs.
- **Changes during a dispatch** follow one rule on every target: each emitter's listeners are taken as they are
  when the dispatch reaches it. A listener may remove itself or add itself again.
- **Removal** finds a bound method on every target, eval, Neko and the jvm included.
- **A listener that throws** reaches the caller with its own value and stack, and leaves the emitter as it was.
- **Storage:** an emitter with no listeners holds two null fields, and works when made by
  `Type.createEmptyInstance`.

### Removed
- `BaseEmitter`, `IBaseEmitter`, `SignalType` to `SignalType5`, `SignalHandler`, `Arity`, `emitUntyped`,
  `dispose`, `callbackCount`, `signalCount`, `totalCallbacks`, `hasSignal`, `removeCallbacks` and `isReady`.
  `removeAllListeners`, `hasSignalListener` and `removeSignalListeners` cover what they did.

## [1.0.0] - 2025-08-04

### Added
- **Arity Enum:** Introduced `Arity` enum to explicitly specify function arity for signal callbacks and once handlers.
    - Added `VarArgs` value for use with `emitUntyped` and signals that expect a variable number of arguments.
- **dispose() Method:** Added `dispose()` to clean up emitter state and release memory resources.
- **Test Suite:** Added comprehensive unit tests for typed signals, callback arity, and emitter behaviors.
- **Continuous Integration:** Introduced Haxe test configuration and GitHub Actions workflow for automated testing.
- **Interfaces:** Added `IBaseEmitter` and `IEmitter` interfaces to formalize emitter contracts.
- **BaseEmitter:** Introduced `BaseEmitter` class separating core signal logic from the concrete `Emitter` implementation.

### Changed
- **Memory Management:** Signals map is now lazily instantiated, reducing GC pressure and improving memory usage for lightweight objects.
- **Improved `once` Handler:** Major enhancements to `once()` usage: now requires explicit arity to ensure correct parameter passing and cross-target compatibility.
- **Untyped Once Handling:** `once` now properly supports untyped emits, allowing one-time handlers for variadic argument signals.
- **Project Structure:** Refactored emitter codebase, moving `Emitter` to extend `BaseEmitter` for clearer separation of responsibilities.
- **Renamed `TypedFunction` to `SignalHandler`**

### Fixed
- **Callback Removal:** Signals are now reliably removed when their last callback is unregistered, preventing lingering empty signal entries.
- **Callback Skipping:** Fixed an issue where certain callbacks could be skipped when emitting signals.
- **HashLink & Neko Compatibility:** Addressed `once` handler issues on HashLink and Neko targets, ensuring stable cross-platform behavior.
- **Documentation:** Corrected documentation for `once()` to properly reflect its usage and signature.

### Breaking
- **Explicit Arity Required:** Using `once()` now requires specifying the callback arity via the new `Arity` enum. This may break existing code that relied on the old signature.
- **Internal API Changes:** Some internal behaviors (such as lazy map instantiation and dispose logic) may require consumers to adjust code that interacts closely with Emitter internals.
- **TypedFunction name changes and Emitter move** Moved Emitter to the root package and renamed TypedFunction for clarity
