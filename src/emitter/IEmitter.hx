package emitter;

/**
	What an event can be dispatched on: an `Emitter`, or a class that keeps
	one inside and hands its calls on. An event's `target` and
	`currentTarget` are typed by it, so a listener written against
	`IEmitter` takes events from any emitter, whichever framework made it.

	Only `dispatch` is here. Listening goes through `Emitter`'s `on`, `once`
	and `off`, which are inlined where they are called and so cannot be
	declared by an interface; a class that holds an emitter offers its own.
**/
interface IEmitter {
	/** Sends `event` to the listeners for its type. See `Emitter.dispatch`. **/
	function dispatch(event:Event):Bool;
}
