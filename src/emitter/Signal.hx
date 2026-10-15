package emitter;

/**
	A signal whose listeners are `F`: what `events.on`, `once`, `off`,
	`has`, `clear` and `emit` take. Declare a signal as one of `Signal0` to
	`Signal5`, which name only the arguments and become this where it is
	used.

	A plain string names a signal too, as in Emitter 1, with a listener of
	any type, an untyped `Function` included:

	```haxe
	emitter.events.on("scored", (points:Int) -> trace(points));
	emitter.events.emit("scored", 10);
	```

	A plain string with a listener that takes an `Event` names an event type
	instead, and so does a plain string alone (`has("ready")`,
	`clear("ready")`): the string becomes an `EventType` more readily than a
	`Signal`. Name a signal by a `Signal0` to `Signal5` constant to ask about
	or clear it.
**/
abstract Signal<F>(String) to String {
	// A function rather than `from String`, so that where a string could be
	// either an event type or a signal, the event type is the closer match.
	@:from static inline function fromName<F>(name:String):Signal<F> {
		return cast name;
	}
}
