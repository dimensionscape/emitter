package emitter;

import haxe.Constraints.Function;
import emitter.signals.SignalType;
import emitter.signals.SignalHandler;

interface IBaseEmitter {
	public function on<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter;
	public function off<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter;
	public function prepend<T>(signal:SignalType<T>, callback:SignalHandler<T>):IBaseEmitter;
	extern public function emit<T>(type:SignalType<T>):Void;
	public function removeCallbacks(signal:SignalType<Dynamic>):Void;
	public function callbackCount(signal:SignalType<Function>):UInt;
	public function signalCount():UInt;
	public function totalCallbacks():UInt;
	public function hasSignal(signal:SignalType<Dynamic>):Bool;
}
