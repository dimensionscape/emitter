package emitter.signals;

import haxe.Rest;
import haxe.Constraints.Function;
import emitter.signals.SignalType;
import emitter.util.TypedFunction;

/**
 * ...
 * @author Christopher Speciale
 */
/**
 * Represents an event emitter that allows registration of listeners for various signals.
 * Signals are automatically removed once their last callback is unregistered,
 * keeping the emitter clean and lightweight.
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
	@:noCompletion private var __onceSignals:Map<String, Array<Function>>;
	@:noCompletion private var __isReady:Bool = false;

	@:noCompletion private inline function get_isReady():Bool {
		return __isReady;
	}

	/**
	 * Returns a boolean value that identifies the underlying memory state.
	 */
	public var isReady(get, never):Bool;

	/**
	 * Creates a new instance of the Emitter class.
	 */
	public function new() {}

	/**
	 * Returns the number of callbacks registered for a specific signal type.
	 *
	 * @param signal A SignalType<Dynamic> object representing the signal for which to count the callbacks.
	 * @return An unsigned integer (UInt) representing the number of callbacks registered for the specified signal type. If the signal does not have any registered callbacks, it returns 0.
	 */
	public function callbackCount(signal:SignalType<Dynamic>):UInt {
		if (__isReady || __signals.exists(signal)) {
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
	 * Emits the specified signal with an arbitrary number of optional arguments.
	 * This method trades type safety for greater flexibility when compared to the type safe
	 * emit methods.
	 * @param type The type of signal to emit.
	 * @param args Additional arguments to pass to the callback functions.
	 */
	public function emitUntyped<T>(type:SignalType<T>, ...args):Void {
		if (!__isReady)
			return;

		var callbacks = __signals.get(type);

		if (callbacks != null) {
			var i = 0;
			while (i < callbacks.length) {
				var cb = callbacks[i];

				switch (args.length) {
					case 0:
						cb();
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

				if (callbacks[i] == cb) {
					i++;
				}
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
		return __isReady && __signals.exists(signal);
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
	public function off<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		if (!__isReady)
			return this;

		if (__signals.exists(signal)) {
			var signalsOfType = __signals.get(signal);

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
	public inline function on<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		// lets lazy init our signals map to ensure lower gc pressure on certain objects
		if (__ensureMap()) {
			__signals.set(signal, [callback]);
		} else {
			__push(signal, callback);
		}

		return this;
	}

	/**
	 * Unregisters a callback function for the specified signal.
	 * @param signal The signal from which to remove the callback.
	 * @param callback The callback function to remove.
	 * @return The Emitter instance for method chaining.
	 */
	public function once<T>(signal:SignalType<T>, callback:TypedFunction<T>, arity:Arity):Emitter {
		if (__ensureMap()) {
			__signals.set(signal, [__onceHandler(signal, callback, arity)]);
		} else {
			__push(signal, __onceHandler(signal, callback, arity));
		}

		return this;
	}

	/**
	 * Adds a callback to the beginning of the callback list for a specific signal type.
	 *
	 * @param signal A SignalType<T> object representing the signal to which to prepend the callback.
	 * @param callback A TypedFunction<T> representing the callback function to prepend.
	 * @return The Emitter object itself, allowing for method chaining.
	 */
	public function prepend<T>(signal:SignalType<T>, callback:TypedFunction<T>):Emitter {
		if (__ensureMap()) {
			__signals.set(signal, [callback]);
		} else {
			if (!__signals.exists(signal)) {
				__signals.set(signal, [callback]);
			} else {
				__signals.get(signal).unshift(callback);
			}
		}

		return this;
	}

	/**
	 * Removes all callbacks associated with a specific signal type.
	 *
	 * @param signal A SignalType<Dynamic> object representing the signal from which to remove all callbacks.
	 */
	public function removeCallbacks(signal:SignalType<Dynamic>):Void {
		if (!__isReady)
			return;

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
		if (!__isReady)
			return 0;

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
		if (!__isReady)
			return 0;

		var count:Int = 0;

		for (key in __signals.keys()) {
			var callbacks = __signals.get(key);
			count += callbacks.length;
		}

		return count;
	}

	@:noCompletion private inline function __deinitSignals():Void {
		__signals.clear();
		__signals = null;
	}

	/*
	 * Returns a boolean valaue indicating whether or not maps were initialized
	 * in this check.
	 */
	@:noCompletion private inline function __ensureMap():Bool {
		if (!__isReady) {
			__initSignals();
			__isReady = true;
			return true;
		}
		return false;
	}

	@:noCompletion private inline function __initSignals():Void {
		__signals = new Map<String, Array<Function>>();
	}

	private inline function __onceHandler<T>(signal:SignalType<T>, callback:TypedFunction<T>, arity:Arity):Function {
		return switch (arity) {
			case Zero: __onceHandler0(signal, callback);
			case One: __onceHandler1(signal, callback);
			case Two: __onceHandler2(signal, callback);
			case Three: __onceHandler3(signal, callback);
			case Four: __onceHandler4(signal, callback);
			case Five: __onceHandler5(signal, callback);
		}
	}

	private inline function __onceHandler0<T>(signal:SignalType<T>, callback:Void->Void):Void->Void {
		var wrapper:Void->Void = null;
		wrapper = function():Void {
			callback();
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __onceHandler1<T, T1>(signal:SignalType<T>, callback:T1->Void):T1->Void {
		var wrapper:T1->Void = null;
		wrapper = function(a:T1):Void {
			callback(a);
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __onceHandler2<T, T1, T2>(signal:SignalType<T>, callback:T1->T2->Void):T1->T2->Void {
		var wrapper:T1->T2->Void = null;
		wrapper = function(a:T1, b:T2):Void {
			callback(a, b);
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __onceHandler3<T, T1, T2, T3>(signal:SignalType<T>, callback:T1->T2->T3->Void):T1->T2->T3->Void {
		var wrapper:T1->T2->T3->Void = null;
		wrapper = function(a:T1, b:T2, c:T3):Void {
			callback(a, b, c);
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __onceHandler4<T, T1, T2, T3, T4>(signal:SignalType<T>, callback:T1->T2->T3->T4->Void):T1->T2->T3->T4->Void {
		var wrapper:T1->T2->T3->T4->Void = null;
		wrapper = function(a:T1, b:T2, c:T3, d:T4):Void {
			callback(a, b, c, d);
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __onceHandler5<T, T1, T2, T3, T4, T5>(signal:SignalType<T>, callback:T1->T2->T3->T4->T5->Void):T1->T2->T3->T4->T5->Void {
		var wrapper:T1->T2->T3->T4->T5->Void = null;
		wrapper = function(a:T1, b:T2, c:T3, d:T4, e:T5):Void {
			callback(a, b, c, d, e);
			off(signal, cast wrapper);
		};
		return wrapper;
	}

	private inline function __push(signal:String, cb:Function):Void {
		var list = __signals.get(signal);
		if (list == null) {
			__signals.set(signal, [cb]);
		} else {
			list.push(cb);
		}
	}
}
