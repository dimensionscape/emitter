package emitter;

import emitter.signals.SignalHandler;
import emitter.signals.SignalType;
import haxe.Constraints.Function;

/**
 * Represents an event emitter that allows registration of listeners for various signals.
 * Signals are automatically removed once their last callback is unregistered,
 * keeping the emitter clean and lightweight.
 * 
 * @see BaseEmitter#on
 * @see BaseEmitter#off
 * @see BaseEmitter#emit
 * @see BaseEmitter#removeCallbacks
 * @see BaseEmitter#callbackCount
 * @see BaseEmitter#signalCount
 * @see BaseEmitter#totalCallbacks
 * @see BaseEmitter#prepend
 * @see BaseEmitter#hasSignal
 */
class BaseEmitter implements IBaseEmitter {
	@:noCompletion private var __signals:Map<String, Array<SignalHandler<Function>>>;
	@:noCompletion private var __isReady:Bool = false;

	public function new() {
		__init();
	}

	public function callbackCount(signal:SignalType<Function>):UInt {
		if (__signals.exists(signal)) {
			var callbacks = __signals.get(signal);

			return callbacks.length;
		} else {
			return 0;
		}
	}

	/**
	 * Emits the specified signal with no arguments
	 * @param type The type of signal to emit.
	 */
	@:keep overload extern public inline function emit<T>(type:SignalType<T>):Void {
		if (!__isReady)
			return;

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
	@:keep overload extern public inline function emit<T, T1>(type:SignalType1<T, T1>, a:T1):Void {
		if (!__isReady)
			return;

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
	@:keep overload extern public inline function emit<T, T1, T2>(type:SignalType2<T, T1, T2>, a:T1, b:T2):Void {
		if (!__isReady)
			return;

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
	@:keep overload extern public inline function emit<T, T1, T2, T3>(type:SignalType3<T, T1, T2, T3>, a:T1, b:T2, c:T3):Void {
		if (!__isReady)
			return;

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
	@:keep overload extern public inline function emit<T, T1, T2, T3, T4>(type:SignalType4<T, T1, T2, T3, T4>, a:T1, b:T2, c:T3, d:T4):Void {
		if (!__isReady)
			return;

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
	@:keep overload extern public inline function emit<T, T1, T2, T3, T4, T5>(type:SignalType5<T, T1, T2, T3, T4, T5>, a:T1, b:T2, c:T3, d:T4, e:T5):Void {
		if (!__isReady)
			return;

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
	 * Determines if the specified signal is registered.
	 *
	 * Signals without callbacks are automatically removed when the last
	 * callback is removed.
	 *
	 * @param signal The signal to check.
	 * @return True if the signal is registered; otherwise, false.
	 */
	public function hasSignal(signal:SignalType<Dynamic>):Bool {
		return __signals.exists(signal);
	}

	/**
	 * Unregisters a callback function for the specified signal.
	 *
	 * If removing the callback leaves the signal with no callbacks, the
	 * signal entry is automatically removed from the emitter.
	 *
	 * @param signal The signal from which to remove the callback.
	 * @param callback The callback function to remove.
	 * @return The Emitter instance for method chaining.
	 */
	public function off<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter {
		var signalsOfType = __signals.get(signal);

		if (signalsOfType != null) {
			var index = signalsOfType.indexOf(callback);
			if (index != -1) {
				signalsOfType.splice(index, 1);

				if (signalsOfType.length == 0) {
					__signals.remove(signal);
				}
			}
		}

		return this;
	}

	/**
	 * Registers a callback function for the specified signal.
	 * @param signal The signal to listen for.
	 * @param callback The callback function to invoke when the signal is emitted.
	 * @return The Emitter instance for method chaining.
	 */
	public function on<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter {
		__push(signal, callback);

		return this;
	}

	/**
	 * Adds a callback to the beginning of the callback list for a specific signal type.
	 *
	 * @param signal A SignalType<T> object representing the signal to which to prepend the callback.
	 * @param callback A SignalHandler<T> representing the callback function to prepend.
	 * @return The Emitter object itself, allowing for method chaining.
	 */
	public function prepend<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter {
		if (!__signals.exists(signal)) {
			__signals.set(signal, [callback]);
		} else {
			__signals.get(signal).unshift(callback);
		}

		return this;
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
	 * Returns the total number of unique signals registered with the Emitter.
	 *
	 * Signals that no longer have callbacks are automatically removed,
	 * so this value always reflects active signals only.
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
	 * Signals that no longer have callbacks are automatically removed,
	 * so the returned value only includes active callbacks.
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

	@:noCompletion private function __init():Void {
		__initSignals();
		__isReady = true;
	}

	@:noCompletion private inline function __initSignals():Void {
		__signals = new Map<String, Array<Function>>();
	}

	@:noCompletion private inline function __push(signal:String, cb:Function):Void {
		var list = __signals.get(signal);
		if (list == null) {
			__signals.set(signal, [cb]);
		} else {
			list.push(cb);
		}
	}
}
