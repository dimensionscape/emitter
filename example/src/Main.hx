package example;

import emitter.signals.Emitter;
import emitter.signals.SignalType;
import haxe.Constraints.Function;

/**
 * ...
 * @author Christopher Speciale
 */
class Main {
	public static inline function main():Void {
		new Example();
	}

	private function new() {
		runExamples();
	}

	function runExamples():Void {
		trace("Execute simple example");
		// Basic example covering a simple untyped use case
		simpleExample();

		trace("Execute tpical example");
		// Typical example covering typed use cases
		typedExample();

		trace("Execute untyped example");
		// Typical example covering untyped use case
		untypedExample();
	}

	function simpleExample():Void {
		// Create an instance of Emitter
		var emitter:Emitter = new Emitter();

		// Define a callback function for the "test" signal
		var callback:Function = function(data:Dynamic) {
			trace("Received number: " + data);
		};

		// Subscribe to the "test" signal
		emitter.on("test", callback);

		// Emit the "test" signal with an argument
		emitter.emit("test", 42);

		// Unsubscribe the callback from the "test" signal
		emitter.off("test", callback);

		trace("");
	}

	function typedExample():Void {
		/*
			We define our Signal in the example.Signal class as follows:
			public static var TEST0:SignalType<Void->Void> = "test0";

			The first type parameter in every SignalType is the function signature. The
			base SignalType expects no arguments to be passed and only has one type parameter.
		 */

		// Create an instance of Emitter
		var emitter:Emitter = new Emitter();

		// Define a callback function the TEST0 signal, with no arguments `Void->Void`
		var callback_TEST0:Void->Void = function() {
			trace("TEST0 Signal received");
		};

		// Subscribe to the "TEST0" signal
		emitter.on(Signal.TEST0, callback_TEST0);

		// Emit the "TEST0" signal with an argument
		emitter.emit(Signal.TEST0);

		// Unsubscribe the callback from the "TEST0" signal
		emitter.off(Signal.TEST0, callback_TEST0);

		/*
			We define our next Signal in the example.Signal class as follows:
			public static var TEST1:SignalType1<String->Void> = "test1";

			The first type parameter in every SignalType1 is the function signature. SignalType1
			expects a single parameter type that defines the type of the argument passed in the signal,
			following the function signature parameter type. In this particular example, the callback
			function expects a String.
		 */

		// Define a callback function the TEST1 signal, with a single string parameter `String->Void`
		var callback_TEST1:String->Void = function(s:String) {
			trace("Received string: " + s);
		};

		// Subscribe to the "TEST1" signal
		emitter.on(Signal.TEST1, callback_TEST1);

		// Emit the "TEST1" signal with an argument
		emitter.emit(Signal.TEST1, "hello world");

		// Unsubscribe the callback from the "TEST1" signal
		emitter.off(Signal.TEST1, callback_TEST1);

		/*
			We define our next Signal in the example.Signal class as follows:
			public static var TEST2:SignalType2<(Int, Float)->Void> = "test2";

			The first type parameter in every SignalType2 is the function signature. SignalType2
			expects a two parameter types that define the type of the arguments passed in the signal,
			following the function signature parameter type. In this particular example, the callback
			function expects an Int followed by a Float.
		 */

		// Define a callback function the TEST2 signal, with a single string parameter `(Int, Float)->Void`
		var callback_TEST2:(Int, Float) -> Void = function(n:Int, x:Float) {
			trace("Received number: " + n + " and floating-point number: " + x);
		};

		// Subscribe to the "TEST2" signal
		emitter.on(Signal.TEST2, callback_TEST2);

		// Emit the "TEST2" signal with an argument
		emitter.emit(Signal.TEST2, 42, 3.14);

		// Unsubscribe the callback from the "TEST2" signal
		emitter.off(Signal.TEST2, callback_TEST2);

		/*
		 * SignalType3
		 * ..
		 */

		trace("Take a look at SignalType3 for similar specs");

		/*
		 * SignalType4
		 * ..
		 */

		trace("Take a look at SignalType4 for similar specs");

		/*
		 * SignalType4
		 * ..
		 */

		trace("Take a look at SignalType5 for similar specs");
		trace("");
	}

	function untypedExample():Void {
		// Create an instance of Emitter
		var emitter:Emitter = new Emitter();

		// Define a callback function for the "test" signal
		var callback:Function = function(s:String, n:Int, x:Float) {
			trace("Received string: " + s + " and number: " + n + " and floating-point number: " + x);
		};

		// Subscribe to the "test" signal
		emitter.on("test", callback);

		// Emit the "test" signal with an arbitrary number or types of arguments using haxe.Rest<Dynamic>
		emitter.emitUntyped("test", "hello word", 42, 3.14);

		// Unsubscribe the callback from the "test" signal
		emitter.off("test", callback);
	}
}
