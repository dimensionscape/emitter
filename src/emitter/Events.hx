package emitter;

import emitter._internal.Lane;
import emitter._internal.Listener;
import haxe.Constraints.Function;

/**
	An emitter's seven verbs: `on`, `once`, `off`, `emit`, `dispatch`, `has`
	and `clear`, reached as `emitter.events`.

	```haxe
	var player = new Emitter();
	var moved = player.events.on(Event.CHANGE, event -> trace(event.type));
	player.events.dispatch(new Event(Event.CHANGE));
	moved.cancel();
	```

	It is a view of the emitter itself, not an object of its own: reaching
	it allocates nothing, and every verb is inlined where it is called, as
	the verbs were when they were the emitter's own members. Keeping them
	here leaves a class built on `Emitter` one name to inherit, and the
	others (`clear`, `dispatch`, `has`) free for its own members.
**/
@:access(emitter.Emitter)
abstract Events(Emitter) {
	@:allow(emitter.Emitter) inline function new(emitter:Emitter) {
		this = emitter;
	}

	/**
		Adds `listener` for events of `type`, and answers with its
		subscription. A higher `priority` runs earlier; listeners of one
		priority run in the order they were added.
		@throws haxe.exceptions.ArgumentException When `type` or `listener` is null.
	**/
	overload extern public inline function on<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Subscription {
		return this.__onEvent(type, listener, priority, Listener.KEPT);
	}

	/**
		Adds `listener` for `signal`, and answers with its subscription. A
		higher `priority` runs earlier; listeners of one priority run in the
		order they were added.
		@throws haxe.exceptions.ArgumentException When `signal` or `listener` is null.
	**/
	overload extern public inline function on<F:Function>(signal:Signal<F>, listener:F, priority:Int = 0):Subscription {
		return this.__onSignal(signal, listener, priority, Listener.SIGNAL);
	}

	/**
		Adds `listener` for the next event of `type` only: it is removed just
		before it is called. Cancel its subscription, or `off`, to remove it
		before then.
	**/
	overload extern public inline function once<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Subscription {
		return this.__onEvent(type, listener, priority, Listener.ONCE);
	}

	/**
		Adds `listener` for the next emit of `signal` only: it is removed just
		before it is called. Cancel its subscription, or `off`, to remove it
		before then.
	**/
	overload extern public inline function once<F:Function>(signal:Signal<F>, listener:F, priority:Int = 0):Subscription {
		return this.__onSignal(signal, listener, priority, Listener.SIGNAL | Listener.ONCE);
	}

	/**
		Removes `listener` for events of `type`: for a method, read again
		(`off(type, this.onChange)`). A lambda is removed by its subscription.
		Nothing happens if it is not there.
	**/
	overload extern public inline function off<T:Event>(type:EventType<T>, listener:T->Void):Void {
		this.__offEvent(type, listener);
	}

	/**
		Removes `listener` for `signal`, the first of them if it was added more
		than once. Nothing happens if it is not there.
	**/
	overload extern public inline function off<F:Function>(signal:Signal<F>, listener:F):Void {
		this.__offSignal(signal, listener);
	}

	/**
		Whether anything listens for events of `type`, or with `listener`
		given, whether that does. Exact at every moment: a listener removed
		during a dispatch is gone from here at once.
	**/
	overload extern public inline function has<T:Event>(type:EventType<T>, ?listener:T->Void):Bool {
		return listener == null ? Emitter.__listened(this.__events, type) : this.__hasEvent(type, listener);
	}

	/** Whether anything listens for `signal`, or with `listener` given, whether that does. **/
	overload extern public inline function has<F:Function>(signal:Signal<F>, ?listener:F):Bool {
		return listener == null ? Emitter.__listened(this.__signals, signal) : this.__hasSignal(signal, listener);
	}

	/** Removes every listener: for every event and every signal. **/
	overload extern public inline function clear():Void {
		this.__clearAll();
	}

	/** Removes every listener for events of `type`. **/
	overload extern public inline function clear<T:Event>(type:EventType<T>):Void {
		this.__clearEvents(type);
	}

	/** Removes every listener for `signal`. **/
	overload extern public inline function clear<F:Function>(signal:Signal<F>):Void {
		this.__clearSignals(signal);
	}

	/**
		Calls each listener for `signal`. Allocates nothing.
		@return Whether anything listened.
	**/
	overload extern public inline function emit(signal:Signal<Void->Void>):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:Void->Void = cast only.fn;
				call();
			} else {
				this.__emit0(lane, signal, list);
			}
		}
		return heard;
	}

	/**
		Calls each listener for `signal` with `a`. Allocates nothing, except
		that natively a primitive argument is boxed to be passed to a
		function value (hxcpp keeps whole numbers from -1 to 255 boxed in
		advance).
		@return Whether anything listened.
	**/
	overload extern public inline function emit<A>(signal:Signal<A->Void>, a:A):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:A->Void = cast only.fn;
				call(a);
			} else {
				this.__emit1(lane, signal, list, a);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` and `b`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B>(signal:Signal<(A, B) -> Void>, a:A, b:B):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B) -> Void = cast only.fn;
				call(a, b);
			} else {
				this.__emit2(lane, signal, list, a, b);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a`, `b` and `c`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C>(signal:Signal<(A, B, C) -> Void>, a:A, b:B, c:C):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C) -> Void = cast only.fn;
				call(a, b, c);
			} else {
				this.__emit3(lane, signal, list, a, b, c);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `d`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D>(signal:Signal<(A, B, C, D) -> Void>, a:A, b:B, c:C, d:D):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C, D) -> Void = cast only.fn;
				call(a, b, c, d);
			} else {
				this.__emit4(lane, signal, list, a, b, c, d);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `e`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D, E>(signal:Signal<(A, B, C, D, E) -> Void>, a:A, b:B, c:C, d:D, e:E):Bool {
		var lane:Null<Lane> = this.__signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C, D, E) -> Void = cast only.fn;
				call(a, b, c, d, e);
			} else {
				this.__emit5(lane, signal, list, a, b, c, d, e);
			}
		}
		return heard;
	}

	/**
		Sends `event` to the listeners for its type.

		Sets the event's `target` to this emitter (or its delegate target)
		when it has none, and its `currentTarget` to each emitter whose
		listeners run. When the event `bubbles`, then goes up through
		`getEventParent()`, running each parent's listeners in turn, until
		there is no parent or a listener stops it; `getEventParent()` is not
		called for an event that does not bubble.

		An event that already has a `target` is taken to be handed on from a
		listener of another emitter: it keeps its target, and gets its
		`currentTarget` back once this dispatch is done, so the listeners
		after that one still see the emitter they listen to. To dispatch an
		event again from scratch, call its `reuse()` first.

		The listeners are handed this very object, not a copy.

		@return Whether any emitter on the way had listeners for it.
	**/
	public inline function dispatch(event:Event):Bool {
		return this.__dispatch(event);
	}
}
