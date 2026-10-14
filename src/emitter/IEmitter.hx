package emitter;

/**
	What can be listened to for events: an `Emitter`, or a class that keeps
	one inside and hands its calls on.

	An event's `target` and `currentTarget` are typed by it, so a listener
	written against `IEmitter` takes events from any emitter, whichever
	framework made it.
**/
interface IEmitter {
	/**
		Adds `listener` for events of `type`. See `Emitter.addEventListener`.
	**/
	function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void;

	/**
		Removes `listener` for events of `type`. See `Emitter.removeEventListener`.
	**/
	function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void;

	/**
		Whether anything listens for events of `type`. See
		`Emitter.hasEventListener`.
	**/
	function hasEventListener(type:String):Bool;

	/**
		Dispatches `event` to the listeners for its type. See
		`Emitter.dispatchEvent`.
	**/
	function dispatchEvent(event:Event):Bool;
}
