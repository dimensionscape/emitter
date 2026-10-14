package emitter;

import emitter._internal.Listener;
import haxe.Constraints.Function;

/**
	A listener as `on` and `once` added it: keep it to remove that listener
	later, a lambda included, with no need to find the function again.

	```haxe
	var moved = player.on(Player.MOVED, (x, y) -> trace(x, y));
	moved.cancel();
	```

	It is the entry the emitter keeps for the listener, so subscribing makes
	no other object.
**/
@:access(emitter.Emitter)
abstract Subscription(Listener) {
	/**
		Whether the listener still listens: false once it is cancelled,
		removed by `off` or `clear`, or, added with `once`, called.
	**/
	public var active(get, never):Bool;

	/**
		The function the listener calls, as the emitter keeps it: for a
		framework that calls a listener itself, having found it with
		`Emitter.listenersOf` or been told of it by `Emitter.listenerAdded`.
		Cast it to its type to call it.

		On HashLink a typed function added through `on` is kept wrapped: the
		wrapper calls it, but is not `==` to the function that was added.
		Tell listeners apart by their subscriptions, which are the same
		everywhere.
	**/
	public var listener(get, never):Function;

	/**
		Whether the listener was added with `once`. A framework that calls a
		listener itself, as `Emitter.listenersOf` lets it, calls a `once`
		listener for one event only and cancels it as it does, as a
		dispatch would.
	**/
	public var once(get, never):Bool;

	inline function new(entry:Listener) {
		this = entry;
	}

	/**
		Removes the listener. Cancelling again, or cancelling a listener
		already gone, does nothing. Cancelled during a dispatch, the listener
		still runs for that dispatch, as one removed by `off` does.
	**/
	public inline function cancel():Void {
		if (this.state & Listener.GONE == 0) {
			this.owner.__cancel(this);
		}
	}

	inline function get_active():Bool {
		return this.state & (Listener.GONE | Listener.SPENT) == 0;
	}

	inline function get_listener():Function {
		return this.fn;
	}

	inline function get_once():Bool {
		return this.state & Listener.ONCE != 0;
	}
}
