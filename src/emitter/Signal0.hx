package emitter;

/**
	The name of a signal that is emitted with no arguments: its listeners are
	`Void->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it. Where it is used it
	becomes a `Signal<Void->Void>`.

	```haxe
	public static inline var READY:Signal0 = "ready";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal0(String) from String to String {
	@:to private inline function toSignal():Signal<Void->Void> {
		return cast this;
	}

	@:op(A == B) private static inline function equals(a:Signal0, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals(a:Signal0, b:String):Bool {
		return (a : String) != b;
	}
}
