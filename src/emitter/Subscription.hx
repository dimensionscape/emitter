package emitter;

import emitter._internal.Listener;

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
}
