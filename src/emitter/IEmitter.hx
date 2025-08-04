package emitter;

import emitter.signals.SignalType;
import emitter.signals.SignalHandler;
import emitter.signals.Arity;
import haxe.Rest;

/**
 * Describes the public API contract for a full-featured signal emitter.
 *
 * This interface extends IBaseEmitter and includes additional functionality
 * such as one-time listeners, untyped emissions, and internal cleanup.
 *
 * @see IBaseEmitter
 */
interface IEmitter extends IBaseEmitter {
	public function once<T>(signal:SignalType<T>, callback:SignalHandler<T>, arity:Arity):Emitter;
	public function emitUntyped<T>(type:SignalType<T>, ...args:Dynamic):Void;
	public function dispose():Void;
	public var isReady(get, never):Bool;
}
