# Emitter

Typed signals and events for Haxe, with nothing allocated to send them.

An `Emitter` holds two kinds of listener:

- **Signals**: typed calls of zero to five arguments. No object is made for them.
- **Events**: an `Event` object sent to the listeners of its type, with priorities, bubbling up a tree of parents,
  stopping and cancelling.

The whole API is seven words: `on`, `once`, `off`, `emit`, `dispatch`, `has` and `clear`. It is tested natively
(hxcpp), on the jvm, Node, eval, HashLink and Neko.

## Installation

```bash
haxelib install emitter
```

Emitter needs Haxe 4.3 or later and has no dependencies.

## Signals

Declare a signal by the arguments it carries, `Signal0` to `Signal5`:

```haxe
import emitter.Emitter;
import emitter.Signal2;

class Player extends Emitter {
	public static inline var MOVED:Signal2<Float, Float> = "moved";

	public function new() {
		super();
	}
}
```

Listen with `on`, and send with `emit`. Both are checked when they are compiled, and a listener's argument types
come from the signal:

```haxe
var player = new Player();
var moved = player.on(Player.MOVED, (x, y) -> trace(x + y));
player.emit(Player.MOVED, 1.5, 2.5); // traces 4
```

`emit` is inlined where it is called, returns whether anything listened, and allocates nothing (natively hxcpp
passes a primitive to a function value boxed, and keeps boxes only for whole numbers from -1 to 255, so an `Int`
outside them or a `Float` is boxed once per emit).

## Events

Declare an event type by the event it carries. The base `Event` has `CHANGE`, `COMPLETE`, `CLOSE` and `CANCEL`; a
class of your own extends it:

```haxe
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
```

The same `on` listens for it, and `dispatch` sends it:

```haxe
var game = new Emitter();
game.on(ScoreEvent.SCORED, event -> trace(event.points));
game.dispatch(new ScoreEvent(10)); // traces 10
```

A listener can call `event.stopPropagation()`, `event.stopImmediatePropagation()` and, on a cancelable event,
`event.preventDefault()`, which the dispatcher reads back as `event.defaultPrevented`. A plain string names an
event type too: `game.on("ready", (event:Event) -> ...)`.

## Removing a listener

`on` and `once` answer with a `Subscription`. Keep it to remove that listener, a lambda included:

```haxe
var moved = player.on(Player.MOVED, (x, y) -> trace(x + y));
moved.cancel();
trace(moved.active); // false
```

`off` removes a listener by its function, which suits a method read again:

```haxe
class Hud {
	public function new(player:Player) {
		player.on(Player.MOVED, onMoved);
		player.off(Player.MOVED, onMoved);
	}

	function onMoved(x:Float, y:Float):Void {}
}
```

`clear(token)` removes every listener of one signal or event type, and `clear()` every listener of both kinds.
`has(token)` says whether anything listens, and `has(token, listener)` whether that listener does.

`once` listens for the next signal or event only. Cancelling a subscription twice, after `clear`, or after its
`once` ran does nothing.

## Order and duplicates

- A higher priority runs earlier: `on(token, listener, priority)`. Listeners of one priority run in the order they
  were added.
- Adding an event listener that is already there does nothing, as in ActionScript, and `on` answers with its
  subscription. Set `allowDuplicates` on an emitter to add it again instead. A signal listener added twice is
  called twice, and each subscription removes its own.

## Bubbling

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
root.on(Event.CHANGE, event -> trace(event.target == leaf)); // true
leaf.dispatch(new Event(Event.CHANGE, true));
```

An event that does not bubble never asks for a parent. `dispatch` sets an event's `target` only when it has none,
so to dispatch the same object again from scratch, as a program that keeps one event per frame does, call
`event.reuse()` first.

## The rules

- **Changes during a dispatch.** Each emitter's listeners are taken as they are when a dispatch reaches it. A
  listener removed or cancelled during the dispatch still runs for it; one added does not, until the next. A
  listener may remove itself, and add itself again. A listener added to a parent the event has not reached yet
  runs for it.
- **Questions are answered as things are**: `has` is exact at every moment, during a dispatch too. A `once` listener
  is gone before it is called.
- **Removal finds what was added** on every target: a subscription is the listener itself, and `off` finds a bound
  method (`this.onMoved`) where each read of it makes a new closure.
- **A listener that throws** stops the dispatch, and what it threw reaches the caller as it was thrown, with its
  stack. The emitter is left as it was.

## Building a framework on it

A framework extends `Emitter` and overrides the hooks it needs:

- `getEventParent()`: the next emitter a bubbling event goes to.
- `listenersChanged(type, present)`: called when an event type gains its first listener or loses its last, by any
  path (`on`, `once`, `off`, a subscription cancelled, a `once` listener called, `clear`). A display tree keeps its
  per-frame registry with it.
- `listenerAdded(type, subscription)` and `listenerRemoved(type, subscription)`: called for each event listener as
  it is added and as it is taken out, by the same paths, as Node's `newListener` and `removeListener` events are.
  A socket that has already closed tells a `close` listener added afterwards what it missed.
- `listenersOf(type)`: the subscriptions listening for an event type, in the order they run, as a copy. With
  `subscription.listener`, the function each calls, a framework calls them some other way: a server that hands
  its `connect` listeners to other threads keeps a copy of them, read again when one comes or goes, and leaves
  out its own by its subscription.
- `dispatchContained(event)` dispatches as `dispatch` does, except that a listener that throws does not stop the
  others: what it threw goes to `listenerThrew(error, event)`, which a framework overrides to report it.
- `dispatchLocal(event)` runs one emitter's listeners and nothing else, for a propagation the framework builds itself.
- `new Emitter(owner)` makes events dispatched through it say `owner` is their target, for a class that keeps an
  emitter inside rather than extending one. `IEmitter` (`dispatch`) is what both have in common.
- `allowDuplicates` keeps an event listener added twice, for an emitter that holds one per connection.

Names a framework's users already know stay its own, each a one-line inline method on its dispatcher, so its call
sites compile unchanged. ActionScript's, as Graphaxe and CrossByte would add them:

```haxe
class EventDispatcher extends emitter.Emitter {
	public inline function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void {
		on(type, listener, priority);
	}

	public inline function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void {
		off(type, listener);
	}

	public inline function hasEventListener(type:String):Bool {
		return has(type);
	}

	public inline function dispatchEvent(event:Event):Bool {
		return dispatch(event);
	}
}
```

An emitter with no listeners holds two null fields and nothing else, and works when made by
`Type.createEmptyInstance`.

## Performance

Dispatch walks the listeners it reached without copying them. A list is copied only when, while a dispatch walks
it, a listener is removed or added anywhere but last. A `once` listener called by the only dispatch walking its
list comes out where it stands, with no copy. On one machine:

| | natively | jvm | Node |
|---|---:|---:|---:|
| dispatch to one listener | 4.7 ns | 2.2 ns | 3.8 ns |
| emit, one argument | 4.9 ns | 2.1 ns | 3.9 ns |
| emit, nothing listening | 3.1 ns | 0.7 ns | 3.3 ns |
| subscribe and cancel | 14.6 ns | 7.9 ns | 9.6 ns |
| `once`, then emit | 22.5 ns | 12.2 ns | 20.7 ns |
| bubble up three emitters, a listener on each | 14.9 ns | 8.3 ns | 15.6 ns |
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
- `on` and `once` answer with a `Subscription` rather than the emitter, so calls no longer chain; `once` takes no
  arity.
- `emit` returns whether anything listened.
- `removeCallbacks(signal)` and `dispose()` are `clear(signal)` and `clear()`; `hasSignal` is `has`.
- `prepend`, `emitUntyped`, `callbackCount`, `signalCount`, `totalCallbacks`, `isReady`, `Arity`,
  `SignalHandler`, `BaseEmitter` and `IBaseEmitter` are gone. A priority puts a listener first.

## License

MIT. See [LICENSE](LICENSE).
