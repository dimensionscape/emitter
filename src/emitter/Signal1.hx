package emitter;

/**
	The name of a signal that is emitted with one argument: its listeners are
	`A->Void`, and `Emitter.emit` takes exactly those, checked when it is
	compiled. No event object is made for it. Where it is used it
	becomes a `Signal<A->Void>`.

	```haxe
	public static inline var SCORED:Signal1<Int> = "scored";
	```

	At run time it is the `String` it was made from. A signal and an event
	may share a name: they are kept apart.
**/
abstract Signal1<A>(String) from String to String {
	@:to private inline function toSignal():Signal<A->Void> {
		return cast this;
	}

	@:op(A == B) private static inline function equals<A>(a:Signal1<A>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<A>(a:Signal1<A>, b:String):Bool {
		return (a : String) != b;
	}
}
