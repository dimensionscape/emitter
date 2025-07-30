package example;

import emitter.signals.SignalType;

/**
 * ...
 * @author Christopher Speciale
 */
class Signal {
	// Example Signal Declaration
	// The way it works is that we define the function signature of the callback in the first type
	// parameter and then we define the argument types for the callbacks follow  type parameters in order
	public static inline var TEST0:SignalType<Void->Void> = "test0";
	public static inline var TEST1:SignalType1<String->Void, String> = "test1";
	public static inline var TEST2:SignalType2<(Int, Float) -> Void, Int, Float> = "test2";
}
