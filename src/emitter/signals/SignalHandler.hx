package emitter.signals;

import haxe.Constraints.Function;

/**
 * ...
 * @author Christopher Speciale
 */
/**
 * Represents a typed function that can be used as a callback.
 * @param T The function type.
 */
@:callable
abstract SignalHandler<T>(Function) from Function to Function to Dynamic {
	@:from private static inline function fromType<T>(t:T):SignalHandler<T> {
		return cast t;
	}
}
