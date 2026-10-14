package emitter;

/**
	The name of a signal that is emitted with four arguments: its listeners are
	`(A, B, C, D)->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it.

	```haxe
	public static inline var RECT:Signal4<Int, Int, Int, Int> = "rect";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal4<A, B, C, D>(String) from String to String {
	@:op(A == B) private static inline function equals<A, B, C, D>(a:Signal4<A, B, C, D>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<A, B, C, D>(a:Signal4<A, B, C, D>, b:String):Bool {
		return (a : String) != b;
	}
}
