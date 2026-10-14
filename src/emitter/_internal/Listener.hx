package emitter._internal;

import haxe.Constraints.Function;

/**
	One listener added to an emitter, for one type on one lane.

	A class rather than an anonymous structure: natively a read of an
	anonymous object's field is a lookup by its name, and dispatch reads
	these for every listener it calls.
**/
@:noCompletion
final class Listener {
	/** An ordinary listener. **/
	public static inline var KEPT:Int = 0;

	/** Added with `once`, and not yet called. **/
	public static inline var ONCE:Int = 1;

	/** Added with `once`, and called: it is never called again. **/
	public static inline var SPENT:Int = 2;

	/** The function as it was added: what is called, and what `off` finds. **/
	public final fn:Function;

	/** Where it runs among the others for its type: higher runs earlier. **/
	public final priority:Int;

	/** `KEPT`, `ONCE` or `SPENT`. **/
	public var state:Int;

	public inline function new(fn:Function, priority:Int, state:Int) {
		this.fn = fn;
		this.priority = priority;
		this.state = state;
	}
}
