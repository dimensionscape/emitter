package emitter;

/**
	An event: the object an `Emitter` hands to each listener of its type.

	A framework extends it for its own events, and keeps its own constants
	on its own subclass; the few here are the ones any framework has.

	## Dispatching one again

	`Emitter.dispatchEvent` sets `target` only when it is null: an event
	that already has one is taken to be handed on from a listener of another
	emitter, and keeps it. So to dispatch the same object again from scratch
	(one event kept per frame, or per arrival on a socket), call `reuse()`
	first, which clears what the last dispatch left on it.
**/
@:allow(emitter.Emitter)
class Event {
	/** Something changed. **/
	public static inline var CHANGE:EventType<Event> = "change";

	/** Something finished. **/
	public static inline var COMPLETE:EventType<Event> = "complete";

	/** Something closed. **/
	public static inline var CLOSE:EventType<Event> = "close";

	/** Something was cancelled. **/
	public static inline var CANCEL:EventType<Event> = "cancel";

	/** What happened: the name listeners are added for. **/
	public var type(default, null):String;

	/**
		Whether `Emitter.dispatchEvent` carries the event up from the emitter
		it is dispatched on, through each `getEventParent()`.
	**/
	public var bubbles(default, null):Bool;

	/** Whether a listener may call `preventDefault()`. **/
	public var cancelable(default, null):Bool;

	/** Whether a listener called `preventDefault()` on a cancelable event. **/
	public var defaultPrevented(get, never):Bool;

	/**
		The emitter the event was dispatched on, or the one it stands in for
		(see `Emitter`'s delegate target). Null until it is dispatched.
	**/
	public var target(default, null):Null<IEmitter>;

	/**
		The emitter whose listeners are running now: `target`, or while the
		event bubbles, the parent it has reached.
	**/
	public var currentTarget(default, null):Null<IEmitter>;

	/**
		Whether a listener called `stopPropagation()` or
		`stopImmediatePropagation()`: no emitter after this one runs its
		listeners.
	**/
	public var propagationStopped(get, never):Bool;

	/**
		Whether a listener called `stopImmediatePropagation()`: no listener
		after that one runs, on this emitter or any other.
	**/
	public var immediatePropagationStopped(get, never):Bool;

	/**
		What a dispatch has done to the event, one bit each: `STOPPED`,
		`STOPPED_NOW` and `PREVENTED`. One field, so `reuse()` clears them
		with one write.
	**/
	@:noCompletion private var __state:Int;

	static inline var STOPPED:Int = 1;
	static inline var STOPPED_NOW:Int = 2;
	static inline var PREVENTED:Int = 4;

	/**
		@param type What happened: the name listeners are added for.
		@param bubbles Whether `dispatchEvent` carries it up the parents.
		@param cancelable Whether a listener may call `preventDefault()`.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false) {
		this.type = type;
		this.bubbles = bubbles;
		this.cancelable = cancelable;
		target = null;
		currentTarget = null;
		__state = 0;
	}

	/**
		Lets the listeners of the emitter the event is at finish, and then
		stops it: no parent runs its listeners.
	**/
	public function stopPropagation():Void {
		__state |= STOPPED;
	}

	/**
		Stops the event now: no listener after the one calling this runs,
		here or on any parent.
	**/
	public function stopImmediatePropagation():Void {
		__state |= STOPPED | STOPPED_NOW;
	}

	/**
		Tells whoever dispatched a cancelable event not to do what it would
		have done next. Does nothing when the event is not `cancelable`.
	**/
	public function preventDefault():Void {
		if (cancelable) {
			__state |= PREVENTED;
		}
	}

	/**
		Makes the event ready to be dispatched again, as a new one is:
		clears `target`, `currentTarget`, both stop flags and
		`defaultPrevented`. For a framework that keeps one event and
		dispatches it again and again rather than making a new one each
		time; a subclass that carries more resets that too.
	**/
	public function reuse():Void {
		target = null;
		currentTarget = null;
		__state = 0;
	}

	/**
		A copy to keep: the same `type`, `bubbles`, `cancelable`,
		`defaultPrevented`, `target` and `currentTarget`. A subclass with
		fields of its own overrides it to copy those too.
	**/
	public function clone():Event {
		var event = new Event(type, bubbles, cancelable);
		event.__state = __state & PREVENTED;
		event.target = target;
		event.currentTarget = currentTarget;
		return event;
	}

	private inline function get_defaultPrevented():Bool {
		return (__state & PREVENTED) != 0;
	}

	private inline function get_propagationStopped():Bool {
		return (__state & STOPPED) != 0;
	}

	private inline function get_immediatePropagationStopped():Bool {
		return (__state & STOPPED_NOW) != 0;
	}

	public function toString():String {
		return '[Event type="$type" bubbles=$bubbles cancelable=$cancelable]';
	}
}
