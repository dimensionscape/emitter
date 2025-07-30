package emitter.signals;

import haxe.Constraints.Function;
import emitter.signals.SignalType;
import emitter.util.TypedFunction;

/**
 * ...
 * @author Christopher Speciale
 */
/**
 * Represents an event emitter that allows registration of listeners for various signals.
 * @see Emitter#on
 * @see Emitter#off
 * @see Emitter#once
 * @see Emitter#emit
 * @see Emitter#emitUntyped
 * @see Emitter#removeCallbacks
 * @see Emitter#callbackCount
 * @see Emitter#signalCount
 * @see Emitter#totalCallbacks
 * @see Emitter#prepend
 * @see Emitter#hasSignal
 */
class Emitter {
	@:noCompletion private var __signals:Map<String, Array<Function>>;

	/**
	 * Creates a new instance of the Emitter class.
	 */
	public function new() {
		__signals = new Map<String, Array<Function>>();
	}

	/**
	 * Registers a callback function for the specified signal.
	 * @param signal The signal to listen for.
	 * @param callback The callback function to invoke when the signal is emitted.
	 * @return The Emitter instance for method chaining.
	 */
	public inline function on<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		if (!__signals.exists(signal)) {
			__signals.set(signal, [callback]);
		} else {
			__signals.get(signal).push(callback);
		}

		return this;
	}

	/**
	 * Unregisters a callback function for the specified signal.
	 * @param signal The signal from which to remove the callback.
	 * @param callback The callback function to remove.
	 * @return The Emitter instance for method chaining.
	 */
	public function off<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		if (__signals.exists(signal)) {
			var signalsOfType = __signals.get(signal);

			var index = signalsOfType.indexOf(callback);
			if (index != -1) {
				signalsOfType.splice(index, 1);
			}
		}

		return this;
	}

	/**
	 * Unregisters a callback function for the specified signal.
	 * @param signal The signal from which to remove the callback.
	 * @param callback The callback function to remove.
	 * @return The Emitter instance for method chaining.
	 */
	public function once<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		// Cast signal to string once
		var signalID:String = signal;

		return on(signalID, __onceHandler(signalID, callback));
	}

	/**
	 * Emits the specified signal with no arguments
	 * @param type The type of signal to emit.
	 */
	overload extern public inline function emit<T>(type:SignalType<T>):Void {
		var callbacks = __signals.get(type);

		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb();
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with one argument.
	 * @param type The type of signal to emit.
	 * @param a The argument to pass to the callback functions.
	 */
	overload extern public inline function emit<T, T1>(type:SignalType1<T, T1>, a:T1):Void {
		var callbacks:Array<Function> = __signals.get(type);

		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb(a);
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with two arguments.
	 * @param type The type of signal to emit.
	 * @param a The first argument to pass to the callback functions.
	 * @param b The second argument to pass to the callback functions.
	 */
	overload extern public inline function emit<T, T1, T2>(type:SignalType2<T, T1, T2>, a:T1, b:T2):Void {
		var callbacks = __signals.get(type);
		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb(a, b);
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with three arguments.
	 * @param type The type of signal to emit.
	 * @param a The first argument to pass to the callback functions.
	 * @param b The second argument to pass to the callback functions.
	 * @param c The third argument to pass to the callback functions.
	 */
	overload extern public inline function emit<T, T1, T2, T3>(type:SignalType3<T, T1, T2, T3>, a:T1, b:T2, c:T3):Void {
		var callbacks = __signals.get(type);
		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb(a, b, c);
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with four arguments.
	 * @param type The type of signal to emit.
	 * @param a The first argument to pass to the callback functions.
	 * @param b The second argument to pass to the callback functions.
	 * @param c The third argument to pass to the callback functions.
	 * @param d The fourth argument to pass to the callback functions.
	 */
	overload extern public inline function emit<T, T1, T2, T3, T4>(type:SignalType4<T, T1, T2, T3, T4>, a:T1, b:T2, c:T3, d:T4):Void {
		var callbacks = __signals.get(type);
		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb(a, b, c, d);
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with five arguments.
	 * @param type The type of signal to emit.
	 * @param a The first argument to pass to the callback functions.
	 * @param b The second argument to pass to the callback functions.
	 * @param c The third argument to pass to the callback functions.
	 * @param d The fourth argument to pass to the callback functions.
	 * @param e The fifth argument to pass to the callback functions.
	 */
	overload extern public inline function emit<T, T1, T2, T3, T4, T5>(type:SignalType5<T, T1, T2, T3, T4, T5>, a:T1, b:T2, c:T3, d:T4, e:T5):Void {
		var callbacks = __signals.get(type);
		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				cb(a, b, c, d, e);
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Emits the specified signal with an arbitrary number of optional arguments.
	 * This method trades type safety for greater flexibility when compared to the type safe
	 * emit methods.
	 * @param type The type of signal to emit.
	 * @param args Additional arguments to pass to the callback functions.
	 */
	public function emitUntyped<T>(type:SignalType<T>, ...args:Dynamic):Void {
		var callbacks = __signals.get(type);
		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];
				if (args == null) {
					cb();
				} else {
					switch (args.length) {
						case 1:
							cb(args[0]);
						case 2:
							cb(args[0], args[1]);
						case 3:
							cb(args[0], args[1], args[2]);
						case 4:
							cb(args[0], args[1], args[2], args[3]);
						case 5:
							cb(args[0], args[1], args[2], args[3], args[4]);
						default:
							Reflect.callMethod(this, cb, args);
					}
				}
				if (callbacks[i] == cb)
					i++;
			}
		}
	}

	/**
	 * Removes all callbacks associated with a specific signal type.
	 *
	 * @param signal A SignalType<Dynamic> object representing the signal from which to remove all callbacks.
	 */
	public function removeCallbacks(signal:SignalType<Dynamic>):Void {
		__signals.remove(signal);
	}

	/**
	 * Returns the number of callbacks registered for a specific signal type.
	 *
	 * @param signal A SignalType<Dynamic> object representing the signal for which to count the callbacks.
	 * @return An unsigned integer (UInt) representing the number of callbacks registered for the specified signal type. If the signal does not have any registered callbacks, it returns 0.
	 */
	public function callbackCount(signal:SignalType<Dynamic>):UInt {
		if (__signals.exists(signal)) {
			var callbacks = __signals.get(signal);

			return callbacks.length;
		} else {
			return 0;
		}
	}

	/**
	 * Returns the total number of unique signals registered with the Emitter.
	 *
	 * @return An unsigned integer (UInt) representing the total number of unique signals registered with the Emitter.
	 */
	public function signalCount():UInt {
		var count:Int = 0;

		for (key in __signals.keys()) {
			count++;
		}

		return count;
	}

	/**
	 * Returns the total number of callbacks registered across all signals.
	 *
	 * @return An unsigned integer (UInt) representing the total number of callbacks registered across all signals.
	 */
	public function totalCallbacks():UInt {
		var count:Int = 0;

		for (key in __signals.keys()) {
			var callbacks = __signals.get(key);
			count += callbacks.length;
		}

		return count;
	}

	/**
	 * Adds a callback to the beginning of the callback list for a specific signal type.
	 *
	 * @param signal A SignalType<T> object representing the signal to which to prepend the callback.
	 * @param callback A TypedFunction<T> representing the callback function to prepend.
	 * @return The Emitter object itself, allowing for method chaining.
	 */
	public function prepend<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		if (!__signals.exists(signal)) {
			__signals.set(signal, [callback]);
		} else {
			__signals.get(signal).unshift(callback);
		}

		return this;
	}

	/**
	 * Determines if the specified signal is registered.
	 * @param signal The signal to check.
	 * @return True if the signal is registered; otherwise, false.
	 */
	public function hasSignal(signal:SignalType<Dynamic>):Bool {
		return __signals.exists(signal);
	}

	private function __onceHandler(signalID:String, callback:Function, retFunc:Function = null):Function {
		return retFunc = function(...args) {
			if (args == null) {
				callback();
			} else {
				switch (args.length) {
					case 1:
						callback(args[0]);
					case 2:
						callback(args[0], args[1]);
					case 3:
						callback(args[0], args[1], args[2]);
					case 4:
						callback(args[0], args[1], args[2], args[3]);
					case 5:
						callback(args[0], args[1], args[2], args[3], args[4]);
					default:
						Reflect.callMethod(this, callback, args);
				}
			}
			off(signalID, retFunc);
		}
	}
}
