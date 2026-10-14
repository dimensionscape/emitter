package emitter;

import emitter._internal.Lane;
import emitter._internal.Listener;
import emitter._internal.Thrown;
import haxe.Constraints.Function;
import haxe.exceptions.ArgumentException;

/**
	Listeners, and the two ways to call them.

	**Signals** are calls: `emit(signal, a, b)` calls each listener with
	those arguments, typed by the signal (`Signal0` to `Signal5`), and makes
	no object at all. **Events** are objects: an `Event`, or a class of your
	own that extends it, sent to the listeners of its `type` by
	`dispatch(event)`. They carry a target, can bubble up a chain of
	parents, and can be stopped and cancelled. The two are kept apart, so an
	event and a signal may share a name.

	```haxe
	var MOVED:Signal2<Float, Float> = "moved";
	var player = new Emitter();
	var moved = player.on(MOVED, (x, y) -> trace(x + y));
	player.emit(MOVED, 1.5, 2.5);
	moved.cancel();

	player.on(Event.CHANGE, event -> trace(event.target));
	player.dispatch(new Event(Event.CHANGE));
	```

	The whole of it: `on` and `once` to listen, each answering with a
	`Subscription` to cancel; `off` to remove a listener by its function;
	`emit` and `dispatch`; `has`; and `clear`.

	## Rules both lanes keep

	- **Order**: the highest priority runs first; listeners of one priority
	  run in the order they were added.
	- **Duplicates**: for events, adding a function already listening for
	  the type does nothing (ActionScript's rule): it keeps its place and
	  priority, and `on` answers with its subscription. Set
	  `allowDuplicates` to add it again instead. A signal listener added
	  twice is called twice.
	- **Changes during a dispatch**: each emitter's listeners for a name are
	  taken as they are when a dispatch reaches it. A listener removed or
	  cancelled during the dispatch still runs for it; one added does not,
	  until the next. A listener added to a parent a bubbling event has not
	  reached yet runs for that very event.
	- **Questions are answered as things are**: `has` says what is there
	  now, also during a dispatch. A `once` listener is gone before it is
	  called.
	- **Removal finds what was added**, on every target: a subscription is
	  the listener itself, and `off` finds a bound method
	  (`off(MOVED, this.onMoved)`) even where each read of it makes a new
	  closure.
	- **A listener that throws** stops the dispatch, and what it threw goes
	  on to the caller as it was thrown (natively with its own stack). The
	  emitter is left as it was. `dispatchContained` instead hands it to
	  `listenerThrew` and goes on with the next listener.

	## Nothing until something listens

	An emitter holds two null fields until a listener is added, so a
	program with thousands of them (a display tree) pays for the ones that
	are listened to. Every field starts null, so an emitter made by
	`Type.createEmptyInstance` works without its constructor.

	## Building on it

	A framework extends `Emitter` and overrides the hooks it needs:
	`getEventParent` to bubble along its own tree, `listenersChanged` to
	learn when a type gains its first listener or loses its last,
	`listenerAdded` and `listenerRemoved` to learn of each listener, and
	`listenerThrew` to report a failure `dispatchContained` caught.
	`dispatchLocal` runs one emitter's listeners for a propagation the
	framework builds itself, and `listenersOf` says who listens, for one
	that calls them some other way. Names a framework's users already know,
	such as `addEventListener`, are one-line inline methods on its own
	subclass.
**/
@:access(emitter.Event)
class Emitter implements IEmitter {
	/** The event lane, made by the first event listener (or a delegate target). **/
	@:noCompletion private var __events:Null<Lane>;

	/** The signal lane, made by the first signal listener. **/
	@:noCompletion private var __signals:Null<Lane>;

	/**
		Whether an event listener added again for a type it is already
		listening for is added again, running once for each add, with each
		`off` removing one of them.

		False by default: adding it again does nothing, as in ActionScript.
		Set it on an emitter that holds a listener per connection or task,
		where adding is not to search the list: with it set, adding costs the
		same however many there are. Changing it leaves the listeners there.

		Signals always keep a listener added twice.
	**/
	public var allowDuplicates(get, set):Bool;

	/**
		@param target What events dispatched here say they were dispatched
		on, as `target` and `currentTarget`: the object that holds this
		emitter and hands its calls on. This emitter itself when null.
	**/
	public function new(?target:IEmitter) {
		__events = target == null ? null : new Lane(target);
		__signals = null;
	}

	// Listening -----------------------------------------------------------

	/**
		Adds `listener` for events of `type`, and answers with its
		subscription. A higher `priority` runs earlier; listeners of one
		priority run in the order they were added.
		@throws haxe.exceptions.ArgumentException When `type` or `listener` is null.
	**/
	overload extern public inline function on<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Subscription {
		return __onEvent(type, listener, priority, Listener.KEPT);
	}

	/**
		Adds `listener` for `signal`, and answers with its subscription. A
		higher `priority` runs earlier; listeners of one priority run in the
		order they were added.
		@throws haxe.exceptions.ArgumentException When `signal` or `listener` is null.
	**/
	overload extern public inline function on<F:Function>(signal:Signal<F>, listener:F, priority:Int = 0):Subscription {
		return __onSignal(signal, listener, priority, Listener.SIGNAL);
	}

	/**
		Adds `listener` for the next event of `type` only: it is removed just
		before it is called. Cancel its subscription, or `off`, to remove it
		before then.
	**/
	overload extern public inline function once<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Subscription {
		return __onEvent(type, listener, priority, Listener.ONCE);
	}

	/**
		Adds `listener` for the next emit of `signal` only: it is removed just
		before it is called. Cancel its subscription, or `off`, to remove it
		before then.
	**/
	overload extern public inline function once<F:Function>(signal:Signal<F>, listener:F, priority:Int = 0):Subscription {
		return __onSignal(signal, listener, priority, Listener.SIGNAL | Listener.ONCE);
	}

	/**
		Removes `listener` for events of `type`: for a method, read again
		(`off(type, this.onChange)`). A lambda is removed by its subscription.
		Nothing happens if it is not there.
	**/
	overload extern public inline function off<T:Event>(type:EventType<T>, listener:T->Void):Void {
		__offEvent(type, listener);
	}

	/**
		Removes `listener` for `signal`, the first of them if it was added more
		than once. Nothing happens if it is not there.
	**/
	overload extern public inline function off<F:Function>(signal:Signal<F>, listener:F):Void {
		__offSignal(signal, listener);
	}

	/**
		Whether anything listens for events of `type`, or with `listener`
		given, whether that does. Exact at every moment: a listener removed
		during a dispatch is gone from here at once.
	**/
	overload extern public inline function has<T:Event>(type:EventType<T>, ?listener:T->Void):Bool {
		return listener == null ? __listened(__events, type) : __hasEvent(type, listener);
	}

	/** Whether anything listens for `signal`, or with `listener` given, whether that does. **/
	overload extern public inline function has<F:Function>(signal:Signal<F>, ?listener:F):Bool {
		return listener == null ? __listened(__signals, signal) : __hasSignal(signal, listener);
	}

	/** Removes every listener: for every event and every signal. **/
	overload extern public inline function clear():Void {
		__clearAll();
	}

	/** Removes every listener for events of `type`. **/
	overload extern public inline function clear<T:Event>(type:EventType<T>):Void {
		__clearEvents(type);
	}

	/** Removes every listener for `signal`. **/
	overload extern public inline function clear<F:Function>(signal:Signal<F>):Void {
		__clearSignals(signal);
	}

	// Signals -------------------------------------------------------------

	/**
		Calls each listener for `signal`. Allocates nothing.
		@return Whether anything listened.
	**/
	overload extern public inline function emit(signal:Signal<Void->Void>):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:Void->Void = cast only.fn;
				call();
			} else {
				__emit0(lane, signal, list);
			}
		}
		return heard;
	}

	/**
		Calls each listener for `signal` with `a`. Allocates nothing, except
		that natively a primitive argument is boxed to be passed to a
		function value (hxcpp keeps whole numbers from -1 to 255 boxed in
		advance).
		@return Whether anything listened.
	**/
	overload extern public inline function emit<A>(signal:Signal<A->Void>, a:A):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:A->Void = cast only.fn;
				call(a);
			} else {
				__emit1(lane, signal, list, a);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` and `b`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B>(signal:Signal<(A, B) -> Void>, a:A, b:B):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B) -> Void = cast only.fn;
				call(a, b);
			} else {
				__emit2(lane, signal, list, a, b);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a`, `b` and `c`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C>(signal:Signal<(A, B, C) -> Void>, a:A, b:B, c:C):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C) -> Void = cast only.fn;
				call(a, b, c);
			} else {
				__emit3(lane, signal, list, a, b, c);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `d`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D>(signal:Signal<(A, B, C, D) -> Void>, a:A, b:B, c:C, d:D):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C, D) -> Void = cast only.fn;
				call(a, b, c, d);
			} else {
				__emit4(lane, signal, list, a, b, c, d);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `e`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D, E>(signal:Signal<(A, B, C, D, E) -> Void>, a:A, b:B, c:C, d:D, e:E):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.SIGNAL) {
				var call:(A, B, C, D, E) -> Void = cast only.fn;
				call(a, b, c, d, e);
			} else {
				__emit5(lane, signal, list, a, b, c, d, e);
			}
		}
		return heard;
	}

	// Events --------------------------------------------------------------

	/**
		Sends `event` to the listeners for its type.

		Sets the event's `target` to this emitter (or its delegate target)
		when it has none, and its `currentTarget` to each emitter whose
		listeners run. When the event `bubbles`, then goes up through
		`getEventParent()`, running each parent's listeners in turn, until
		there is no parent or a listener stops it; `getEventParent()` is not
		called for an event that does not bubble.

		An event that already has a `target` is taken to be handed on from a
		listener of another emitter: it keeps its target, and gets its
		`currentTarget` back once this dispatch is done, so the listeners
		after that one still see the emitter they listen to. To dispatch an
		event again from scratch, call its `reuse()` first.

		The listeners are handed this very object, not a copy.

		@return Whether any emitter on the way had listeners for it.
	**/
	public function dispatch(event:Event):Bool {
		if (event == null) {
			return false;
		}
		if (event.target != null) {
			return __dispatchOnward(event, false);
		}
		if (event.bubbles) {
			return __dispatchFurther(event, false);
		}
		// An event of its own that stays here: the usual case, kept short
		// so that a compiler inlining it inlines all of it.
		var lane:Null<Lane> = __events;
		if (lane == null) {
			event.target = this;
			return false;
		}
		var list:Null<Array<Listener>> = lane.listOf(event.type);
		if (list == null) {
			event.target = lane.target == null ? this : lane.target;
			return false;
		}
		var owner:IEmitter = lane.target == null ? this : lane.target;
		event.target = owner;
		event.currentTarget = owner;
		var only:Listener = list[0];
		if (list.length == 1 && only.state == Listener.KEPT) {
			var call:Event->Void = cast only.fn;
			call(event);
		} else {
			__walk(lane, list, event);
		}
		return true;
	}

	// Hooks and paths for frameworks ---------------------------------------

	/**
		Runs this emitter's listeners for `event`, and nothing else: sets its
		`currentTarget` when there are any, leaves its `target` as it is, and
		does not bubble, whatever `event.bubbles` says.

		For a framework that carries events along a path it builds itself,
		such as a chain of display objects under a pointer worked out once
		per frame.

		@return Whether this emitter had listeners for it.
	**/
	public final function dispatchLocal(event:Event):Bool {
		return event == null ? false : __local(event);
	}

	/**
		Dispatches `event` as `dispatch` does, except that a listener that
		throws does not stop the ones after it: what it threw goes to
		`listenerThrew`, and the dispatch carries on.

		For events whose listeners belong to unrelated parts of a program (a
		runtime's tick, its start and its exit), where one's failure is not
		the others' business. A separate method rather than a flag, so the
		ordinary dispatch pays nothing for it.
	**/
	public function dispatchContained(event:Event):Bool {
		if (event == null) {
			return false;
		}
		return __dispatchFurther(event, true);
	}

	/**
		The emitter a bubbling event goes to after this one; null, the
		default, for none. A framework with a tree returns the parent.
	**/
	public function getEventParent():Null<Emitter> {
		return null;
	}

	/**
		Called when events of `type` gain their first listener (`present`
		true) or lose their last (false), by whatever path: `on`, `once`,
		`off`, a subscription cancelled, a `once` listener being called, or
		`clear`. A listener added again and ignored changes nothing, and is
		not reported. Called after the change, so `has` already says so.
		Does nothing here; a framework overrides it to keep a registry, such
		as the objects that want a call every frame.

		Only the event lane reports: a signal may share an event's name.
	**/
	private function listenersChanged(type:String, present:Bool):Void {}

	/**
		Called after `listener` is added for events of `type`, by `on` or
		`once`: for every listener added, the first of its type included
		(after `listenersChanged` says the type has listeners now). A
		listener added again and ignored is not added, and is not reported.
		Does nothing here; a framework overrides it to act on each listener
		as it comes, as Node's `newListener` event lets one: to tell a
		listener added too late what it missed, say.

		Only the event lane reports, as for `listenersChanged`.
	**/
	private function listenerAdded(type:String, listener:Subscription):Void {}

	/**
		Called after `listener` is taken out of the listeners for events of
		`type`, by whatever path: `off`, its subscription cancelled, a `once`
		listener being called, or `clear` (once for each listener it takes
		out). When it was the type's last, `listenersChanged` follows. Does
		nothing here; a framework that keeps a record of the listeners, such
		as a copy it hands to another thread, overrides it with
		`listenerAdded` to keep the record whole.
	**/
	private function listenerRemoved(type:String, listener:Subscription):Void {}

	/**
		The listeners for events of `type` now, in the order a dispatch
		calls them: a copy, which the emitter never changes, and empty when
		nothing listens. Each is the listener's subscription, so a framework
		tells one from another (its own, say) by identity, on every target,
		and calls one through `Subscription.listener`.

		For a framework that hands events to the listeners some other way,
		from a thread of its own for instance, with `listenerAdded` and
		`listenerRemoved` telling it when to read this again.
	**/
	private function listenersOf(type:String):Array<Subscription> {
		var lane:Null<Lane> = __events;
		var list:Null<Array<Listener>> = (lane == null || type == null) ? null : lane.listOf(type);
		return list == null ? [] : cast list.copy();
	}

	/**
		What `dispatchContained` does with what a listener threw: traces it
		here, with its stack. A framework overrides it to report the failure
		its own way.
	**/
	private function listenerThrew(error:haxe.Exception, event:Event):Void {
		haxe.Log.trace("A \"" + event.type + "\" listener threw: " + error.details(), null);
	}

	// Inside --------------------------------------------------------------

	private function get_allowDuplicates():Bool {
		var lane:Null<Lane> = __events;
		return lane != null && lane.keepDuplicates;
	}

	private function set_allowDuplicates(value:Bool):Bool {
		var lane:Null<Lane> = __events;
		if (lane == null) {
			lane = new Lane(null);
			__events = lane;
		}
		lane.keepDuplicates = value;
		return value;
	}

	// The event paths take the listener through a generic signature, the
	// same for adding, removing and asking: HashLink wraps a typed function
	// passed through one, and a listener wrapped one way would not be found
	// by a removal that wrapped it another.

	@:noCompletion private function __onEvent<T:Event>(type:EventType<T>, listener:T->Void, priority:Int, state:Int):Subscription {
		if (listener == null) {
			__refuse("listener");
		}
		var lane:Null<Lane> = __events;
		if (lane == null) {
			lane = new Lane(null);
			__events = lane;
		}
		var entry:Listener = new Listener(listener, priority, state, this, type);
		var result:Int = lane.add(type, entry, !lane.keepDuplicates);
		if (result >= 0) {
			// There already: its subscription is the answer.
			return cast lane.listOf(type)[result];
		}
		if (result == Lane.TRANSITION) {
			listenersChanged(type, true);
		}
		listenerAdded(type, cast entry);
		return cast entry;
	}

	@:noCompletion private function __offEvent<T:Event>(type:EventType<T>, listener:T->Void):Void {
		var lane:Null<Lane> = __events;
		if (lane == null || listener == null) {
			return;
		}
		var list:Null<Array<Listener>> = lane.listOf(type);
		var at:Int = list == null ? -1 : Lane.indexOf(list, listener);
		if (at >= 0) {
			var entry:Listener = list[at];
			__removed(type, entry, lane.removeAt(type, list, at));
		}
	}

	@:noCompletion private function __hasEvent<T:Event>(type:EventType<T>, listener:T->Void):Bool {
		var lane:Null<Lane> = __events;
		return lane != null && lane.has(type, listener);
	}

	@:noCompletion private function __onSignal(signal:String, listener:Function, priority:Int, state:Int):Subscription {
		if (listener == null) {
			__refuse("listener");
		}
		var lane:Null<Lane> = __signals;
		if (lane == null) {
			lane = new Lane(null);
			__signals = lane;
		}
		var entry:Listener = new Listener(listener, priority, state, this, signal);
		lane.add(signal, entry, false);
		return cast entry;
	}

	@:noCompletion private function __offSignal(signal:String, listener:Function):Void {
		var lane:Null<Lane> = __signals;
		if (lane != null && listener != null) {
			lane.removeListener(signal, listener);
		}
	}

	@:noCompletion private function __hasSignal(signal:String, listener:Function):Bool {
		var lane:Null<Lane> = __signals;
		return lane != null && lane.has(signal, listener);
	}

	/**
		Whether anything listens for `type` on `lane`. Where names are chained,
		the first name always has listeners, so its list is not read; both
		null is no name at all.
	**/
	@:noCompletion private static function __listened(lane:Null<Lane>, type:String):Bool {
		if (lane == null) {
			return false;
		}
		#if (cpp || js)
		if (Lane.sameString(lane.type, type)) {
			return type != null;
		}
		return lane.listAfter(type) != null;
		#elseif jvm
		var hash:Int = Lane.hashOf(type);
		if (lane.hash == hash && Lane.sameText(lane.type, type)) {
			return true;
		}
		return lane.listAfter(type, hash) != null;
		#else
		return lane.listOf(type) != null;
		#end
	}

	/** `Subscription.cancel`, for a listener not yet gone. **/
	@:noCompletion private function __cancel(entry:Listener):Void {
		var signal:Bool = entry.state & Listener.SIGNAL != 0;
		var lane:Null<Lane> = signal ? __signals : __events;
		if (lane == null) {
			return;
		}
		var result:Int = lane.removeEntry(entry.type, entry);
		if (result != Lane.NOT_FOUND && !signal) {
			__removed(entry.type, entry, result);
		}
	}

	/**
		Reports an event listener taken out: to `listenerRemoved`, and then,
		when it was its type's last (`result` is `Lane.TRANSITION`), to
		`listenersChanged`.
	**/
	@:noCompletion private function __removed(type:String, entry:Listener, result:Int):Void {
		listenerRemoved(type, cast entry);
		if (result == Lane.TRANSITION) {
			listenersChanged(type, false);
		}
	}

	@:noCompletion private function __clearEvents(type:String):Void {
		var lane:Null<Lane> = __events;
		var list:Null<Array<Listener>> = lane == null ? null : lane.removeType(type);
		if (list != null) {
			__clearedType(type, list);
		}
	}

	/** Reports the listeners `clear` took out of one type, and then the type. **/
	@:noCompletion private function __clearedType(type:String, list:Array<Listener>):Void {
		for (entry in list) {
			listenerRemoved(type, cast entry);
		}
		listenersChanged(type, false);
	}

	@:noCompletion private function __clearSignals(signal:String):Void {
		var lane:Null<Lane> = __signals;
		if (lane != null) {
			lane.removeType(signal);
		}
	}

	@:noCompletion private function __clearAll():Void {
		var signals:Null<Lane> = __signals;
		if (signals != null) {
			// Back to holding nothing. A dispatch walking one of its lists
			// keeps the lane it started with.
			__signals = null;
			signals.clearAll();
		}
		var lane:Null<Lane> = __events;
		if (lane == null) {
			return;
		}
		if (lane.target == null && !lane.keepDuplicates) {
			__events = null;
		}
		var lists:Null<Array<Array<Listener>>> = lane.clearAll();
		if (lists != null) {
			for (list in lists) {
				__clearedType(list[0].type, list);
			}
		}
	}

	/** Throws for an add given a null `argument`. **/
	@:noCompletion private function __refuse(argument:String):Void {
		throw new ArgumentException(argument, "An emitter's " + argument + " must not be null");
	}

	/**
		Runs this emitter's listeners for `event`: `dispatchLocal`, and each
		step of a bubbling dispatch. One listener is called straight away,
		with nothing to keep count of; more are walked by `__walk`.
	**/
	@:noCompletion private inline function __local(event:Event):Bool {
		var lane:Null<Lane> = __events;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(event.type);
		var heard:Bool = list != null;
		if (heard) {
			event.currentTarget = lane.target != null ? lane.target : this;
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:Event->Void = cast only.fn;
				call(event);
			} else {
				__walk(lane, list, event);
			}
		}
		return heard;
	}

	/**
		Walks `list`, the listeners for `event` when the dispatch reached
		this emitter. While the walk is counted in `lane.walking`, removing
		and inserting replace the lane's array rather than change it, so
		nothing changes this one under the walk.
	**/
	@:noCompletion private function __walk(lane:Lane, list:Array<Listener>, event:Event):Void {
		var type:String = event.type;
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT) {
					var verdict:Int = __mayRun(lane, type, entry, true, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:Event->Void = cast entry.fn;
				call(event);
				if (event.immediatePropagationStopped) {
					break;
				}
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	/** `__local`, with each listener's failure handed to `listenerThrew`. **/
	@:noCompletion private function __localContained(event:Event):Bool {
		var lane:Null<Lane> = __events;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(event.type);
		if (list == null) {
			return false;
		}
		event.currentTarget = lane.target != null ? lane.target : this;
		var type:String = event.type;
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT) {
					var verdict:Int = __mayRun(lane, type, entry, true, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				try {
					var call:Event->Void = cast entry.fn;
					call(event);
				} catch (error:haxe.Exception) {
					listenerThrew(error, event);
				}
				if (event.immediatePropagationStopped) {
					break;
				}
				i++;
			}
		} catch (error:Thrown) {
			// listenerThrew or listenersChanged threw: the count is put back.
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
		return true;
	}

	/** This emitter's listeners, then each parent's, while nothing stops the event. **/
	@:noCompletion private function __bubble(event:Event, contained:Bool):Bool {
		var heard:Bool = contained ? __localContained(event) : __local(event);
		var node:Null<Emitter> = this;
		while (!event.propagationStopped) {
			node = node.getEventParent();
			if (node == null) {
				break;
			}
			if (contained ? node.__localContained(event) : node.__local(event)) {
				heard = true;
			}
		}
		return heard;
	}

	/**
		Every dispatch but `dispatch`'s usual one: one that bubbles, and every
		contained dispatch.
	**/
	@:noCompletion private function __dispatchFurther(event:Event, contained:Bool):Bool {
		if (event.target != null) {
			return __dispatchOnward(event, contained);
		}
		var lane:Null<Lane> = __events;
		event.target = (lane != null && lane.target != null) ? lane.target : this;
		return if (event.bubbles) {
			__bubble(event, contained);
		} else if (contained) {
			__localContained(event);
		} else {
			__local(event);
		}
	}

	/**
		Dispatches an event a listener of another emitter handed on here, and
		gives it back its `currentTarget` when done, by returning or by
		throwing: the dispatch it came from goes on to its next listener,
		which listens there, not here.
	**/
	@:noCompletion private function __dispatchOnward(event:Event, contained:Bool):Bool {
		var previous:Null<IEmitter> = event.currentTarget;
		var heard:Bool = false;
		try {
			heard = if (event.bubbles) {
				__bubble(event, contained);
			} else if (contained) {
				__localContained(event);
			} else {
				__local(event);
			}
		} catch (error:Thrown) {
			event.currentTarget = previous;
			Rethrow.rethrow(error);
		}
		event.currentTarget = previous;
		return heard;
	}

	/** What `__mayRun` says of a listener walked: not to call it. **/
	static inline var SKIP:Int = 0;

	/** To call it. **/
	static inline var RUN:Int = 1;

	/** To call it, and that it came out of the list walked where it was: the walk does not move on. **/
	static inline var RUN_HERE:Int = 2;

	/**
		Whether a listener walked, `list[at]`, that is not plainly kept runs.
		One removed or cancelled during the dispatch still does. A `once` is
		taken out before it is called, and not called if it has been already:
		a dispatch nested inside another reached it first, and the outer one
		still holds it in the list it is walking. Taken out by the only walk
		of its lane, over the lane's own list, it comes out of that list where
		it is (`RUN_HERE`), so no copy is made for the walk.
	**/
	@:noCompletion private function __mayRun(lane:Lane, type:String, entry:Listener, events:Bool, list:Array<Listener>, at:Int):Int {
		var state:Int = entry.state;
		if (state & Listener.ONCE == 0) {
			return RUN;
		}
		if (state & Listener.SPENT != 0) {
			return SKIP;
		}
		entry.state = state | Listener.SPENT;
		var verdict:Int = RUN;
		var removed:Int;
		if (lane.walking == 1 && lane.listOf(type) == list) {
			removed = lane.removeWalked(type, list, at);
			verdict = RUN_HERE;
		} else {
			removed = lane.removeEntry(type, entry);
		}
		// Not found when `off` or `cancel` took it out during this dispatch,
		// which still runs it: that removal was reported then.
		if (events && removed != Lane.NOT_FOUND) {
			__removed(type, entry, removed);
		}
		return verdict;
	}

	// The walks `emit` hands over to past a single listener: generic, so
	// natively an argument is boxed once for all the listeners.

	@:noCompletion private function __emit0(lane:Lane, signal:String, list:Array<Listener>):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:Void->Void = cast entry.fn;
				call();
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit1<A>(lane:Lane, signal:String, list:Array<Listener>, a:A):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:A->Void = cast entry.fn;
				call(a);
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit2<A, B>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:(A, B) -> Void = cast entry.fn;
				call(a, b);
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit3<A, B, C>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:(A, B, C) -> Void = cast entry.fn;
				call(a, b, c);
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit4<A, B, C, D>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C, d:D):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:(A, B, C, D) -> Void = cast entry.fn;
				call(a, b, c, d);
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit5<A, B, C, D, E>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C, d:D, e:E):Void {
		var length:Int = list.length;
		var i:Int = 0;
		lane.walking++;
		try {
			while (i < length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.SIGNAL) {
					var verdict:Int = __mayRun(lane, signal, entry, false, list, i);
					if (verdict == SKIP) {
						i++;
						continue;
					}
					if (verdict == RUN_HERE) {
						// It came out where it stood: the next moved into its place.
						length--;
						i--;
					}
				}
				var call:(A, B, C, D, E) -> Void = cast entry.fn;
				call(a, b, c, d, e);
				i++;
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}
}
