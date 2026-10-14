package emitter;

/**
	The name of a signal that is emitted with two arguments: its listeners are
	`(A, B)->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it.

	```haxe
	public static inline var MOVED:Signal2<Float, Float> = "moved";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal2<A, B>(String) from String to String {
	@:op(A == B) private static inline function equals<A, B>(a:Signal2<A, B>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<A, B>(a:Signal2<A, B>, b:String):Bool {
		return (a : String) != b;
	}
}
