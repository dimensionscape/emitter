## [2.0.0] - 2026-10-14

A redesign: one `Emitter` carries typed signals and events on one dispatch core, with a small API (`on`, `once`,
`off`, `emit`, `dispatch`, `has`, `clear`, reached through `emitter.events`) and hooks for frameworks to build on. The 1.x API is replaced, not kept
alongside.

### Added
- **Events:** `Event` (type, target, current target, bubbling, stop and cancel, `reuse`, `clone`), `EventType<T>`
  typing a listener by its event, and `dispatch(event)`.
- **`events`:** the verbs live on `emitter.events`, a view of the emitter itself (nothing is made for it, and each
  verb is inlined where it is called), so a class built on `Emitter` inherits one name and keeps `clear`, `has`,
  `dispatch` and the rest for members of its own. `IEmitter` is `events`.
- **`EventTarget`:** an event's `target` and `currentTarget` are taken as the class they are, without a cast
  (`var player:Player = event.target`), and a class that is no emitter does not compile. At run time it is the
  `IEmitter` itself, and taking it as a class is the cast, inlined.
- **Subscriptions:** `on` and `once` answer with a `Subscription`; `cancel()` removes that listener, a lambda
  included, with no function equality needed, and `active` says whether it still listens.
- **`has(token, ?listener)`** and **`clear(?token)`** for both signals and events.
- **Bubbling** through `getEventParent()`, asked only for an event that bubbles; `stopPropagation` and
  `stopImmediatePropagation`.
- **Priorities** on both kinds, highest first.
- **Duplicate policy:** an event listener added again is ignored, as in ActionScript, and `on` answers with its
  subscription; `allowDuplicates` keeps it instead. Signals keep duplicates.
- **Hooks for frameworks:** `listenersChanged(type, present)` from every path that adds or removes,
  `listenerAdded` and `listenerRemoved` for each listener by the same paths, `listenersOf(type)` listing a type's
  subscriptions in the order they run, `Subscription.listener` and `Subscription.once`, `dispatchContained` with `listenerThrew`,
  `dispatchLocal`, a delegate target (`new Emitter(owner)`), and `IEmitter`. A framework adds names its users know
  (`addEventListener` and the rest) as inline methods of its own.
- **Tests** on hxcpp, the jvm, Node, eval, HashLink and Neko (`haxe test/all.hxml`), and a benchmark
  (`haxe bench/all.hxml`).

### Changed
- **Signals** are `Signal0` to `Signal5`, typed by their arguments only (`Signal1<Int>` for
  `SignalType1<Int->Void, Int>`). `emit` is inlined, allocates nothing, and returns whether anything listened.
- **`once`** takes no arity; cancelling its subscription, or `off`, removes it before it runs.
- **`on` and `once`** answer with a subscription, so calls no longer chain.
- **A signal nothing listens for** is found absent at once, faster than in 1.x.
- **Changes during a dispatch** follow one rule on every target: each emitter's listeners are taken as they are
  when the dispatch reaches it. A listener may remove itself or add itself again.
- **Removal** finds a bound method on every target, eval, Neko and the jvm included.
- **A listener that throws** reaches the caller with its own value and stack, and leaves the emitter as it was.
- **Storage:** an emitter with no listeners holds two null fields, and works when made by
  `Type.createEmptyInstance`.

### Removed
- `BaseEmitter`, `IBaseEmitter`, `SignalType` to `SignalType5`, `SignalHandler`, `Arity`, `prepend`,
  `emitUntyped`, `dispose`, `callbackCount`, `signalCount`, `totalCallbacks`, `hasSignal`, `removeCallbacks` and
  `isReady`. `clear` and `has` cover what they did; a priority puts a listener first.

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
