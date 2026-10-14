package emitter;

/**
	The name of a signal that is emitted with five arguments: its listeners are
	`(A, B, C, D, E)->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it.

	```haxe
	public static inline var SPAWNED:Signal5<String, Float, Float, Int, Bool> = "spawned";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal5<A, B, C, D, E>(String) from String to String {
	@:op(A == B) private static inline function equals<A, B, C, D, E>(a:Signal5<A, B, C, D, E>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<A, B, C, D, E>(a:Signal5<A, B, C, D, E>, b:String):Bool {
		return (a : String) != b;
	}
}
