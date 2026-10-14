package emitter;

import emitter._internal.Lane;
import emitter._internal.Listener;
import emitter._internal.Thrown;
import haxe.Constraints.Function;
import haxe.exceptions.ArgumentException;

/**
	Listeners, and the two ways to call them.

	**Events** are objects: an `Event`, or a class of your own that extends
	it, dispatched to the listeners of its `type` with `dispatchEvent`. They
	carry a target, can bubble up a chain of parents, and can be stopped and
	cancelled. `addEventListener` and `removeEventListener` are their
	ActionScript names; `on`, `off`, `once` and `prepend` take them too.

	**Signals** are calls: `emit(signal, a, b)` calls each listener with
	those arguments, typed by the signal (`Signal0` to `Signal5`), and makes
	no object at all.

	The two are kept apart, so an event and a signal may share a name.

	```haxe
	var button = new Emitter();
	button.addEventListener(Event.CHANGE, function(event:Event):Void trace("changed"));
	button.dispatchEvent(new Event(Event.CHANGE));

	var SCORED:Signal1<Int> = "scored";
	button.on(SCORED, function(points:Int):Void trace(points)).emit(SCORED, 10);
	```

	## Rules both lanes keep

	- **Order**: the highest priority runs first; listeners of one priority
	  run in the order they were added, and `prepend` puts one first among
	  its priority. With no priorities given, first in, first out.
	- **Duplicates**: on the event lane, adding a listener that is already
	  there for the type does nothing (ActionScript's rule): it keeps its
	  place and its priority. Set `allowDuplicates` to add it again instead.
	  On the signal lane a listener added twice is called twice.
	- **Changes during a dispatch**: each emitter's listeners for a type are
	  taken as they are when a dispatch reaches it. A listener removed
	  during the dispatch still runs for it; one added does not, until the
	  next. An emitter a bubbling event has not reached yet is taken as it
	  is when the event gets there, so a listener added to a parent from a
	  child's listener runs for that very event.
	- **Questions are answered as things are**: `hasEventListener`,
	  `hasSignalListener` and `has` say what is there now, also during a
	  dispatch. A `once` listener is gone before it is called.
	- **Removal finds what was added**, on every target: a bound method
	  (`removeEventListener(type, this.onClose)`) is found even where each
	  read of it makes a new closure.
	- **A listener that throws** stops the dispatch, and what it threw goes
	  on to the caller as it was thrown (natively with its own stack). The
	  emitter is left as it was. `dispatchContained` instead hands it to
	  `listenerThrew` and goes on with the next listener.

	## Nothing until something listens

	An emitter holds two null fields until a listener is added, so a
	program with thousands of them (a display tree) pays for the ones that
	are listened to. Every field starts null, so an emitter made by
	`Type.createEmptyInstance` works without its constructor.

	## Adapting it

	A framework extends `Emitter` and overrides the hooks it needs:
	`getEventParent` to bubble along its own tree, `listenersChanged` to
	learn when a type gains its first listener or loses its last, and
	`listenerThrew` to report a failure `dispatchContained` caught.
	`dispatchLocal` runs one emitter's listeners for a propagation the
	framework builds itself.
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
		`removeEventListener` removing one of them.

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

	// Events --------------------------------------------------------------

	/**
		Adds `listener` for events of `type`.

		@param priority Where it runs among the others for `type`: higher
		runs earlier, and any `Int` will do. Those of one priority run in the
		order they were added.
		@throws haxe.exceptions.ArgumentException When `type` or `listener` is null.
	**/
	public function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void {
		__addEvent(type, listener, priority, false, Listener.KEPT);
	}

	/**
		Removes `listener` for events of `type`, the first of them if
		`allowDuplicates` let it be added more than once. Nothing happens if
		it is not there.
	**/
	public function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void {
		var lane:Null<Lane> = __events;
		if (lane != null && listener != null && lane.removeListener(type, listener) == Lane.TRANSITION) {
			listenersChanged(type, false);
		}
	}

	/**
		Whether anything listens for events of `type`. Exact at every moment:
		a listener removed during a dispatch is gone from here at once. To ask
		about one listener, `has(type, listener)`.
	**/
	public function hasEventListener(type:String):Bool {
		var lane:Null<Lane> = __events;
		if (lane == null) {
			return false;
		}
		#if (cpp || js || jvm)
		// The first chained type always has listeners: its list need not be
		// read. Both null is no type at all.
		if (Lane.sameString(lane.type, type)) {
			return type != null;
		}
		return lane.listAfter(type) != null;
		#else
		return lane.listOf(type) != null;
		#end
	}

	/**
		Removes every listener for events of `type`, or with no type, for
		every event.
	**/
	public function removeEventListeners(?type:String):Void {
		var lane:Null<Lane> = __events;
		if (lane == null) {
			return;
		}
		if (type != null) {
			if (lane.removeType(type)) {
				listenersChanged(type, false);
			}
			return;
		}
		if (lane.target == null && !lane.keepDuplicates) {
			// Back to holding nothing. A dispatch walking one of its lists
			// keeps the lane it started with.
			__events = null;
		}
		var types:Null<Array<String>> = lane.clearAll();
		if (types != null) {
			for (gone in types) {
				listenersChanged(gone, false);
			}
		}
	}

	/**
		Dispatches `event` to the listeners for its type.

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
	public function dispatchEvent(event:Event):Bool {
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
		Dispatches `event` as `dispatchEvent` does, except that a listener
		that throws does not stop the ones after it: what it threw goes to
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
		true) or lose their last (false), by whatever path: an add, `once`,
		`prepend`, a removal, a `once` listener being called, or removing
		them all. A listener added again and ignored changes nothing, and is
		not reported. Called after the change, so `hasEventListener` already
		says so. Does nothing here; a framework overrides it to keep a
		registry, such as the objects that want a call every frame.

		Only the event lane reports: a signal may share an event's name.
	**/
	private function listenersChanged(type:String, present:Bool):Void {}

	/**
		What `dispatchContained` does with what a listener threw: traces it
		here, with its stack. A framework overrides it to report the failure
		its own way.
	**/
	private function listenerThrew(error:haxe.Exception, event:Event):Void {
		haxe.Log.trace("A \"" + event.type + "\" listener threw: " + error.details(), null);
	}

	// Both lanes ----------------------------------------------------------

	/**
		Adds `listener` for events of `type`: `addEventListener`, returning
		this emitter.
	**/
	overload extern public inline function on<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Emitter {
		addEventListener(type, listener, priority);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on(signal:Signal0, listener:Void->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on<A>(signal:Signal1<A>, listener:A->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on<A, B>(signal:Signal2<A, B>, listener:(A, B) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on<A, B, C>(signal:Signal3<A, B, C>, listener:(A, B, C) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on<A, B, C, D>(signal:Signal4<A, B, C, D>, listener:(A, B, C, D) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, after the others of its priority. **/
	overload extern public inline function on<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, listener:(A, B, C, D, E) -> Void,
			priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.KEPT);
		return this;
	}

	/**
		Removes `listener` for events of `type`: `removeEventListener`,
		returning this emitter. Also cancels a `once` not yet called.
	**/
	overload extern public inline function off<T:Event>(type:EventType<T>, listener:T->Void):Emitter {
		removeEventListener(type, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off(signal:Signal0, listener:Void->Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off<A>(signal:Signal1<A>, listener:A->Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off<A, B>(signal:Signal2<A, B>, listener:(A, B) -> Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off<A, B, C>(signal:Signal3<A, B, C>, listener:(A, B, C) -> Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off<A, B, C, D>(signal:Signal4<A, B, C, D>, listener:(A, B, C, D) -> Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/** Removes `listener` for `signal` (the first, if added more than once); also a pending `once`. **/
	overload extern public inline function off<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, listener:(A, B, C, D, E) -> Void):Emitter {
		__removeSignal(signal, listener);
		return this;
	}

	/**
		Adds `listener` for the next event of `type` only: it is removed
		just before it is called. `off(type, listener)` cancels it before
		then. On the event lane a listener already there is not added again.
	**/
	overload extern public inline function once<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Emitter {
		__onceEvent(type, listener, priority);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once(signal:Signal0, listener:Void->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once<A>(signal:Signal1<A>, listener:A->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once<A, B>(signal:Signal2<A, B>, listener:(A, B) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once<A, B, C>(signal:Signal3<A, B, C>, listener:(A, B, C) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once<A, B, C, D>(signal:Signal4<A, B, C, D>, listener:(A, B, C, D) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/** Adds `listener` for the next emit of `signal` only; `off(signal, listener)` cancels it. **/
	overload extern public inline function once<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, listener:(A, B, C, D, E) -> Void,
			priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, false, Listener.ONCE);
		return this;
	}

	/**
		Adds `listener` for events of `type`, first among those of its
		priority. On the event lane a listener already there is not added
		again, and keeps its place.
	**/
	overload extern public inline function prepend<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Emitter {
		__prependEvent(type, listener, priority);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend(signal:Signal0, listener:Void->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend<A>(signal:Signal1<A>, listener:A->Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend<A, B>(signal:Signal2<A, B>, listener:(A, B) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend<A, B, C>(signal:Signal3<A, B, C>, listener:(A, B, C) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend<A, B, C, D>(signal:Signal4<A, B, C, D>, listener:(A, B, C, D) -> Void, priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/** Adds `listener` for `signal`, first among those of its priority. **/
	overload extern public inline function prepend<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, listener:(A, B, C, D, E) -> Void,
			priority:Int = 0):Emitter {
		__addSignal(signal, listener, priority, true, Listener.KEPT);
		return this;
	}

	/**
		Whether `listener` listens for events of `type`; with no listener,
		whether anything does (`hasEventListener`).
	**/
	overload extern public inline function has<T:Event>(type:EventType<T>, ?listener:T->Void):Bool {
		return listener == null ? hasEventListener(type) : __hasEvent(type, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has(signal:Signal0, ?listener:Void->Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has<A>(signal:Signal1<A>, ?listener:A->Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has<A, B>(signal:Signal2<A, B>, ?listener:(A, B) -> Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has<A, B, C>(signal:Signal3<A, B, C>, ?listener:(A, B, C) -> Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has<A, B, C, D>(signal:Signal4<A, B, C, D>, ?listener:(A, B, C, D) -> Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	/** Whether `listener` listens for `signal`; with no listener, whether anything does. **/
	overload extern public inline function has<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, ?listener:(A, B, C, D, E) -> Void):Bool {
		return listener == null ? hasSignalListener(signal) : __hasSignal(signal, listener);
	}

	// Signals -------------------------------------------------------------

	/**
		Calls each listener for `signal`. Allocates nothing.
		@return Whether anything listened.
	**/
	overload extern public inline function emit(signal:Signal0):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
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
		function value (hxcpp keeps small integers boxed in advance).
		@return Whether anything listened.
	**/
	overload extern public inline function emit<A>(signal:Signal1<A>, a:A):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:A->Void = cast only.fn;
				call(a);
			} else {
				__emit1(lane, signal, list, a);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` and `b`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B>(signal:Signal2<A, B>, a:A, b:B):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:(A, B) -> Void = cast only.fn;
				call(a, b);
			} else {
				__emit2(lane, signal, list, a, b);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a`, `b` and `c`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C>(signal:Signal3<A, B, C>, a:A, b:B, c:C):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:(A, B, C) -> Void = cast only.fn;
				call(a, b, c);
			} else {
				__emit3(lane, signal, list, a, b, c);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `d`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D>(signal:Signal4<A, B, C, D>, a:A, b:B, c:C, d:D):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:(A, B, C, D) -> Void = cast only.fn;
				call(a, b, c, d);
			} else {
				__emit4(lane, signal, list, a, b, c, d);
			}
		}
		return heard;
	}

	/** Calls each listener for `signal` with `a` to `e`. @return Whether anything listened. **/
	overload extern public inline function emit<A, B, C, D, E>(signal:Signal5<A, B, C, D, E>, a:A, b:B, c:C, d:D, e:E):Bool {
		var lane:Null<Lane> = __signals;
		var list:Null<Array<Listener>> = lane == null ? null : lane.listOf(signal);
		var heard:Bool = list != null;
		if (heard) {
			var only:Listener = list[0];
			if (list.length == 1 && only.state == Listener.KEPT) {
				var call:(A, B, C, D, E) -> Void = cast only.fn;
				call(a, b, c, d, e);
			} else {
				__emit5(lane, signal, list, a, b, c, d, e);
			}
		}
		return heard;
	}

	/**
		Whether anything listens for `signal`. Exact at every moment, as
		`hasEventListener` is. To ask about one listener, `has(signal, listener)`.
	**/
	public function hasSignalListener(signal:String):Bool {
		var lane:Null<Lane> = __signals;
		if (lane == null) {
			return false;
		}
		#if (cpp || js || jvm)
		if (Lane.sameString(lane.type, signal)) {
			return signal != null;
		}
		return lane.listAfter(signal) != null;
		#else
		return lane.listOf(signal) != null;
		#end
	}

	/** Removes every listener for `signal`, or with no signal, for every signal. **/
	public function removeSignalListeners(?signal:String):Void {
		var lane:Null<Lane> = __signals;
		if (lane == null) {
			return;
		}
		if (signal != null) {
			lane.removeType(signal);
			return;
		}
		__signals = null;
		lane.clearAll();
	}

	/** Removes every listener: for every event and every signal. **/
	public function removeAllListeners():Void {
		removeSignalListeners();
		removeEventListeners();
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

	// Inlined into the three ways in, so adding is one call to the lane.
	@:noCompletion private inline function __addEvent(type:String, listener:Function, priority:Int, prepend:Bool, state:Int):Void {
		// A null type is refused by the lane, on the path it always takes.
		if (listener == null) {
			__refuse("listener");
		}
		var lane:Null<Lane> = __events;
		if (lane == null) {
			lane = new Lane(null);
			__events = lane;
		}
		if (lane.add(type, listener, priority, prepend, state, !lane.keepDuplicates) == Lane.TRANSITION) {
			listenersChanged(type, true);
		}
	}

	// `once` and `prepend` for events take the listener through a generic
	// signature, as addEventListener and removeEventListener do: HashLink
	// wraps a typed function passed through one, and a listener wrapped one
	// way would not be found by a removal that wrapped it another.

	@:noCompletion private function __onceEvent<T:Event>(type:EventType<T>, listener:T->Void, priority:Int):Void {
		__addEvent(type, listener, priority, false, Listener.ONCE);
	}

	@:noCompletion private function __prependEvent<T:Event>(type:EventType<T>, listener:T->Void, priority:Int):Void {
		__addEvent(type, listener, priority, true, Listener.KEPT);
	}

	@:noCompletion private function __hasEvent<T:Event>(type:EventType<T>, listener:T->Void):Bool {
		var lane:Null<Lane> = __events;
		return lane != null && lane.has(type, listener);
	}

	@:noCompletion private function __hasSignal(signal:String, listener:Function):Bool {
		var lane:Null<Lane> = __signals;
		return lane != null && lane.has(signal, listener);
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
		this emitter. While the walk is counted in `lane.walking`, adding and
		removing replace the lane's array rather than change it, so nothing
		changes this one under the walk.
	**/
	@:noCompletion private function __walk(lane:Lane, list:Array<Listener>, event:Event):Void {
		var type:String = event.type;
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, type, entry, true)) {
					continue;
				}
				var call:Event->Void = cast entry.fn;
				call(event);
				if (event.immediatePropagationStopped) {
					break;
				}
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
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, type, entry, true)) {
					continue;
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
		Every dispatch but `dispatchEvent`'s usual one: an event handed on
		from another emitter (its `target` set), one that bubbles, and every
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

	/**
		Takes a `once` listener out before it is called. False when it has
		been called already: a dispatch nested inside another reached it
		first, and the outer one still holds it in the list it is walking.
	**/
	@:noCompletion private function __spend(lane:Lane, type:String, entry:Listener, events:Bool):Bool {
		if (entry.state == Listener.SPENT) {
			return false;
		}
		entry.state = Listener.SPENT;
		if (lane.removeEntry(type, entry) == Lane.TRANSITION && events) {
			listenersChanged(type, false);
		}
		return true;
	}

	@:noCompletion private function __addSignal(signal:String, listener:Function, priority:Int, prepend:Bool, state:Int):Void {
		if (signal == null || listener == null) {
			__refuse(signal == null ? "signal" : "listener");
		}
		var lane:Null<Lane> = __signals;
		if (lane == null) {
			lane = new Lane(null);
			__signals = lane;
		}
		lane.add(signal, listener, priority, prepend, state, false);
	}

	/** Throws for an add given a null `argument`. **/
	@:noCompletion private function __refuse(argument:String):Void {
		throw new ArgumentException(argument, "An emitter's " + argument + " must not be null");
	}

	@:noCompletion private function __removeSignal(signal:String, listener:Function):Void {
		var lane:Null<Lane> = __signals;
		if (lane != null && listener != null) {
			lane.removeListener(signal, listener);
		}
	}

	// The walks `emit` hands over to past a single listener: generic, so
	// natively an argument is boxed once for all the listeners.

	@:noCompletion private function __emit0(lane:Lane, signal:String, list:Array<Listener>):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:Void->Void = cast entry.fn;
				call();
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit1<A>(lane:Lane, signal:String, list:Array<Listener>, a:A):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:A->Void = cast entry.fn;
				call(a);
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit2<A, B>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:(A, B) -> Void = cast entry.fn;
				call(a, b);
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit3<A, B, C>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:(A, B, C) -> Void = cast entry.fn;
				call(a, b, c);
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit4<A, B, C, D>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C, d:D):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:(A, B, C, D) -> Void = cast entry.fn;
				call(a, b, c, d);
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}

	@:noCompletion private function __emit5<A, B, C, D, E>(lane:Lane, signal:String, list:Array<Listener>, a:A, b:B, c:C, d:D, e:E):Void {
		var length:Int = list.length;
		lane.walking++;
		try {
			for (i in 0...length) {
				var entry:Listener = list[i];
				if (entry.state != Listener.KEPT && !__spend(lane, signal, entry, false)) {
					continue;
				}
				var call:(A, B, C, D, E) -> Void = cast entry.fn;
				call(a, b, c, d, e);
			}
		} catch (error:Thrown) {
			lane.walking--;
			Rethrow.rethrow(error);
		}
		lane.walking--;
	}
}
