package emitter._internal;

import haxe.Constraints.Function;

/**
	One listener added to an emitter, for one name on one lane. It is also
	what `on` and `once` hand back as a `Subscription`: the entry the lane
	keeps anyway, so subscribing makes no other object.

	A class rather than an anonymous structure: natively a read of an
	anonymous object's field is a lookup by its name, and dispatch reads
	these for every listener it calls.
**/
@:noCompletion
final class Listener {
	/** An ordinary listener, listening. **/
	public static inline var KEPT:Int = 0;

	/** Added with `once`. **/
	public static inline var ONCE:Int = 1;

	/** Added with `once`, and called: it is never called again. **/
	public static inline var SPENT:Int = 2;

	/** Taken out of its list: removed, cancelled, cleared, or a `once` called. **/
	public static inline var GONE:Int = 4;

	/** On the signal lane rather than the event lane. **/
	public static inline var SIGNAL:Int = 8;

	/** The function as it was added: what is called, and what `off` finds. **/
	public final fn:Function;

	/** Where it runs among the others for its name: higher runs earlier. **/
	public final priority:Int;

	/**
		`KEPT`, or `ONCE`, `SPENT`, `GONE` and `SIGNAL` together. Dispatch
		reads only whether it is `KEPT`, the one state with nothing to check.
	**/
	public var state:Int;

	/** The emitter it was added to, which `Subscription.cancel` asks to remove it. **/
	public final owner:Emitter;

	/** The name it listens for. **/
	public final type:String;

	public inline function new(fn:Function, priority:Int, state:Int, owner:Emitter, type:String) {
		this.fn = fn;
		this.priority = priority;
		this.state = state;
		this.owner = owner;
		this.type = type;
	}
}
