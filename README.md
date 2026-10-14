# Emitter

Typed events and signals for Haxe, with nothing allocated to dispatch them.

An `Emitter` holds two kinds of listener:

- **Events**: an `Event` object dispatched to the listeners of its type, as in ActionScript, with priorities,
  bubbling up a tree of parents, stopping and cancelling.
- **Signals**: typed calls of zero to five arguments. No object is made for them.

It is tested natively (hxcpp), on the jvm, Node, eval, HashLink and Neko.

## Installation

```bash
haxelib install emitter
```

Emitter needs Haxe 4.3 or later and has no dependencies.

## Events

An event type is a name typed by the event it names, so a listener's argument is checked when it is added:

```haxe
import emitter.Emitter;
import emitter.Event;
import emitter.EventType;

class ScoreEvent extends Event {
	public static inline var SCORED:EventType<ScoreEvent> = "scored";

	public var points:Int;

	public function new(points:Int) {
		super(SCORED);
		this.points = points;
	}
}

var game = new Emitter();
game.addEventListener(ScoreEvent.SCORED, function(event:ScoreEvent) trace(event.points));
game.dispatchEvent(new ScoreEvent(10)); // traces 10
```

- `addEventListener(type, listener, priority = 0)` adds a listener. The highest priority runs first, and listeners
  of one priority run in the order they were added.
- `on`, `off`, `once` and `prepend` do the same and return the emitter, so calls chain. `once` listens for the
  next event only, and `off(type, listener)` cancels it before then. `prepend` puts a listener first among its
  priority.
- Adding a listener that is already there does nothing, as in ActionScript. Set `allowDuplicates` on an emitter
  to add it again instead.
- `removeEventListener(type, listener)` removes one; `removeEventListeners(type)` all of a type, or with no
  type all of them; `removeAllListeners()` every event and signal listener.
- `hasEventListener(type)` says whether anything listens; `has(type, listener)` whether that listener does.
- A listener can call `event.stopPropagation()`, `event.stopImmediatePropagation()` and, on a cancelable event,
  `event.preventDefault()`, which the dispatcher reads back as `event.defaultPrevented`.

`Event` carries `type`, `target`, `currentTarget`, `bubbles`, `cancelable` and `defaultPrevented`, and the
generic types `Event.CHANGE`, `Event.COMPLETE`, `Event.CLOSE` and `Event.CANCEL`.

### Bubbling

An emitter in a tree returns its parent from `getEventParent()`. An event made with `bubbles` set then goes up
through each parent after the emitter it was dispatched on, until a listener stops it:

```haxe
class Node extends Emitter {
	public var parent:Null<Node>;

	public function new(?parent:Node) {
		super();
		this.parent = parent;
	}

	override public function getEventParent():Null<Emitter> {
		return parent;
	}
}

var root = new Node();
var leaf = new Node(root);
root.addEventListener(Event.CHANGE, function(event:Event) trace(event.target == leaf)); // true
leaf.dispatchEvent(new Event(Event.CHANGE, true));
```

An event that does not bubble never asks for a parent.

### Dispatching one event again

`dispatchEvent` sets an event's `target` only when it has none: an event that already has one is taken to be
handed on from another emitter's listener, and keeps it. To dispatch the same object again from scratch, as a
program that keeps one event per frame does, call `event.reuse()` first.

## Signals

A signal is a name typed by the arguments it is emitted with, `Signal0` to `Signal5`:

```haxe
import emitter.Emitter;
import emitter.Signal2;

class Player extends Emitter {
	public static inline var MOVED:Signal2<Float, Float> = "moved";

	public function new() {
		super();
	}
}

var player = new Player();
player.on(Player.MOVED, function(x:Float, y:Float) trace(x + y));
player.emit(Player.MOVED, 1.5, 2.5); // traces 4
```

`emit` is checked when it is compiled, is inlined where it is called, and returns whether anything listened.
It allocates nothing, with one exception natively: hxcpp passes a primitive to a function value boxed, and only
whole numbers from -1 to 255 have their boxes made in advance, so an emit with any other `Int` or `Float`
argument boxes it once.

`on`, `off`, `once`, `prepend` and `has` work for signals as they do for events. A listener added twice for a
signal is called twice. A signal and an event may share a name: they are kept apart.

`on`, `off`, `once`, `prepend` and `has` tell an event from a signal by the type of the name, so they need an
`EventType` or a `Signal0` to `Signal5`; with a plain `String`, use `addEventListener` and its siblings.

## The rules

- **Changes during a dispatch.** Each emitter's listeners are taken as they are when a dispatch reaches it. A
  listener removed during the dispatch still runs for it; one added does not, until the next. A listener may
  remove itself, and add itself again. A listener added to a parent the event has not reached yet runs for it.
- **Questions are answered as things are**: `hasEventListener`, `hasSignalListener` and `has` are exact at every
  moment, during a dispatch too. A `once` listener is gone before it is called.
- **Removal finds what was added** on every target, a bound method (`this.onClose`) included.
- **A listener that throws** stops the dispatch, and what it threw reaches the caller as it was thrown, with its
  stack. The emitter is left as it was.

## Building on it

A framework extends `Emitter` and overrides the hooks it needs:

- `getEventParent()`: the next emitter a bubbling event goes to.
- `listenersChanged(type, present)`: called when an event type gains its first listener or loses its last, by
  any path (add, `once`, `prepend`, a removal, a `once` listener being called, removing them all). A display
  tree keeps its per-frame registry with it.
- `dispatchContained(event)` dispatches as `dispatchEvent` does, except that a listener that throws does not stop
  the others: what it threw goes to `listenerThrew(error, event)`, which a framework overrides to report it.
- `dispatchLocal(event)` runs one emitter's listeners and nothing else, for a propagation the framework builds
  itself.
- `new Emitter(owner)` makes events dispatched through it say `owner` is their target, for a class that keeps
  an emitter inside rather than extending one. `IEmitter` is what both have in common.

An emitter with no listeners holds two null fields and nothing else, and works when made by
`Type.createEmptyInstance`.

## Performance

Dispatch walks the listeners it reached without copying them; a list is copied only when it is changed while a
dispatch walks it. On one machine:

| | natively | jvm | Node |
|---|---:|---:|---:|
| dispatch to one listener | 4.6 ns | 2.2 ns | 3.7 ns |
| dispatch to four listeners | 13.8 ns | 2.1 ns | 8.1 ns |
| emit, one argument | 4.8 ns | 2.2 ns | 3.7 ns |
| bubble up three emitters, a listener on each | 14.4 ns | 7.7 ns | 15.2 ns |
| allocated by a dispatch or an emit | 0 | 0 | |
| an emitter with no listeners | 32 bytes | 24 bytes | |

`haxe bench/all.hxml` measures them on yours, beside the same cases for other dispatchers (see `bench/RunBench.hx`).

## Tests

```bash
haxe test/all.hxml                 # every target
haxe test/all.hxml eval node jvm   # those named
```

Run from the repository's root, with utest installed, hxnodejs for Node and hxcpp natively. `test/` has one
hxml per target. `HL` and `NEKO` name the HashLink and Neko runtimes when they are not on the `PATH`.

## Upgrading from 1.x

- `SignalType` and `SignalType1` to `SignalType5` become `Signal0` to `Signal5`, typed by their arguments only:
  `SignalType1<Int->Void, Int>` is `Signal1<Int>`.
- `once` takes no arity.
- `emit` returns whether anything listened.
- `removeCallbacks(signal)` is `removeSignalListeners(signal)`, `hasSignal` is `hasSignalListener`, and
  `dispose()` is `removeAllListeners()`.
- `emitUntyped`, `callbackCount`, `signalCount`, `totalCallbacks`, `isReady`, `Arity`, `SignalHandler`,
  `BaseEmitter` and `IBaseEmitter` are gone.

## License

MIT. See [LICENSE](LICENSE).
