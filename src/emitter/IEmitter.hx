package emitter;

/**
	What an event can be dispatched on: an `Emitter`, or a class that keeps
	one inside and hands its calls on. An event's `target` and
	`currentTarget` are typed by it, so a listener written against
	`IEmitter` takes events from any emitter, whichever framework made it,
	and reaches its verbs: `event.target.events.dispatch(other)`.

	A class that holds an emitter rather than extending one answers with
	that emitter's `events`; made with this class as its delegate target,
	the emitter says events dispatched through it were dispatched on this.
**/
interface IEmitter {
	/** The emitter's verbs: see `Events`. **/
	var events(get, never):Events;
}
