package emitter.signals;

/**
 * ...
 * @author Christopher Speciale
 */
/**
 * Represents a generic signal type.
 * @param T The type of data associated with the signal.
 */
abstract SignalType<T>(String) from String to String {
	@:op(A == B) private static inline function equals<T>(a:SignalType<T>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T>(a:SignalType<T>, b:String):Bool {
		return (a : String) != b;
	}
}

/**
 * Represents a generic signal type with one additional type parameter.
 * @param T The type of data associated with the signal.
 * @param T1 The type of additional data associated with the signal.
 */
abstract SignalType1<T, T1>(SignalType<T>) from String to String to SignalType<T> {
	@:op(A == B) private static inline function equals<T, T1>(a:SignalType1<T, T1>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T, T1>(a:SignalType1<T, T1>, b:String):Bool {
		return (a : String) != b;
	}
}

/**
 * Represents a generic signal type with two additional type parameters.
 * @param T The type of data associated with the signal.
 * @param T1 The type of additional data associated with the signal.
 * @param T2 Another type of additional data associated with the signal.
 */
abstract SignalType2<T, T1, T2>(SignalType<T>) from String to String to SignalType<T> {
	@:op(A == B) private static inline function equals<T, T1, T2>(a:SignalType2<T, T1, T2>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T, T1, T2>(a:SignalType2<T, T1, T2>, b:String):Bool {
		return (a : String) != b;
	}
}

abstract SignalType3<T, T1, T2, T3>(SignalType<T>) from String to String to SignalType<T> {
	@:op(A == B) private static inline function equals<T, T1, T2, T3>(a:SignalType3<T, T1, T2, T3>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T, T1, T2, T3>(a:SignalType3<T, T1, T2, T3>, b:String):Bool {
		return (a : String) != b;
	}
}

abstract SignalType4<T, T1, T2, T3, T4>(SignalType<T>) from String to String to SignalType<T> {
	@:op(A == B) private static inline function equals<T, T1, T2, T3, T4>(a:SignalType4<T, T1, T2, T3, T4>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T, T1, T2, T3, T4>(a:SignalType4<T, T1, T2, T3, T4>, b:String):Bool {
		return (a : String) != b;
	}
}

abstract SignalType5<T, T1, T2, T3, T4, T5>(SignalType<T>) from String to String to SignalType<T> {
	@:op(A == B) private static inline function equals<T, T1, T2, T3, T4, T5>(a:SignalType5<T, T1, T2, T3, T4, T5>, b:String):Bool {
		return (a : String) == b;
	}

	@:op(A != B) private static inline function notEquals<T, T1, T2, T3, T4, T5>(a:SignalType5<T, T1, T2, T3, T4, T5>, b:String):Bool {
		return (a : String) != b;
	}
}
