package emitter._internal;

/**
	What a dispatch catches from a listener to throw it on, untouched: the
	same value, with the stack it was thrown from where the target keeps one.

	Natively, on Neko and on HashLink the value thrown, rethrown by the
	target's own rethrow (`cpp.Lib.rethrow`, `neko.Lib.rethrow`,
	`hl.Api.rethrow`), which keeps its stack. On JavaScript and the jvm a
	`haxe.Exception`, whose `throw` throws the native exception it was caught
	as. On eval the value, thrown again. Catching it any other way wraps a
	thrown value that is not an exception in a new one, with a new stack.
**/
@:noCompletion
typedef Thrown = #if (js || jvm) haxe.Exception #else Dynamic #end;

@:noCompletion
class Rethrow {
	/** Throws `error` on as it was thrown. Never returns. **/
	public static inline function rethrow(error:Thrown):Void {
		#if cpp
		cpp.Lib.rethrow(error);
		#elseif neko
		neko.Lib.rethrow(error);
		#elseif hl
		hl.Api.rethrow(error);
		#else
		throw error;
		#end
	}
}
