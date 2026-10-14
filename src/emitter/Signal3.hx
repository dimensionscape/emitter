package emitter;

/**
	The name of a signal that is emitted with three arguments: its listeners are
	`(A, B, C)->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it.

	```haxe
	public static inline var HIT:Signal3<Entity, Entity, Int> = "hit";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal3<A, B, C>(String) from String to String {
	@:op(A == B) private static inline function equals<A, B, C>(a:Signal3<A, B, C>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<A, B, C>(a:Signal3<A, B, C>, b:String):Bool {
		return (a : String) != b;
	}
}
