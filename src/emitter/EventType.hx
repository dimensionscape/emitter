package emitter;

/**
	The name of an event, typed by the event it names: a listener added for
	an `EventType<T>` is a `T->Void`, checked when it is added.

	```haxe
	class LoadEvent extends emitter.Event {
		public static inline var LOADED:EventType<LoadEvent> = "loaded";
	}

	emitter.on(LoadEvent.LOADED, event -> trace(event.type));
	```

	At run time it is the `String` it was made from: nothing is allocated
	for it, and it compares with a `String` as one.
**/
abstract EventType<T:Event>(String) from String to String {
	@:op(A == B) private static inline function equals<T:Event>(a:EventType<T>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T:Event>(a:EventType<T>, b:String):Bool {
		return (a : String) != b;
	}
}
