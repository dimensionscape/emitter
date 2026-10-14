package emitter._internal;

/**
	What a dispatch catches from a listener to throw it on, untouched.

	Natively the value thrown, rethrown by `cpp.Lib.rethrow` with the stack
	it was thrown from. Elsewhere a `haxe.Exception`, whose `throw` throws
	the native exception it was caught as, so its stack and identity are
	kept too; catching `Dynamic` there would wrap a thrown value in a new
	exception, with a new stack.
**/
@:noCompletion
typedef Thrown = #if cpp Dynamic #else haxe.Exception #end;

@:noCompletion
class Rethrow {
	/** Throws `error` on as it was thrown. Never returns. **/
	public static inline function rethrow(error:Thrown):Void {
		#if cpp
		cpp.Lib.rethrow(error);
		#else
		throw error;
		#end
	}
}
