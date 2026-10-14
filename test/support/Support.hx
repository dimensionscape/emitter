package support;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import emitter.Subscription;

/** An emitter in a tree: bubbling goes to `parent`, and counts how often it is asked. **/
class Node extends Emitter {
	public var parent:Null<Node>;
	public var name:String;

	/** How many times `getEventParent` was called. **/
	public var parentReads:Int = 0;

	public function new(name:String, ?parent:Node, ?target:IEmitter) {
		super(target);
		this.name = name;
		this.parent = parent;
	}

	override public function getEventParent():Null<Emitter> {
		parentReads++;
		return parent;
	}

	public function toString():String {
		return name;
	}
}

/**
	An emitter in a tree with no field initialisers of its own, for
	`Type.createEmptyInstance`, which skips them.
**/
class BareNode extends Emitter {
	public var parent:Null<Emitter>;

	public function new() {
		super();
	}

	override public function getEventParent():Null<Emitter> {
		return parent;
	}
}

/** An emitter that records what its hooks were told. **/
class Recording extends Emitter {
	/** `listenersChanged` calls, as `type+` or `type-`. **/
	public var changes:Array<String> = [];

	/** What `hasEventListener(type)` said inside each `listenersChanged` call. **/
	public var presentInside:Array<Bool> = [];

	/** `listenerThrew` calls, as the message and the event type. **/
	public var thrown:Array<String> = [];

	public var throwFromHook:Bool = false;

	public function new(?target:IEmitter) {
		super(target);
	}

	override private function listenersChanged(type:String, present:Bool):Void {
		changes.push(type + (present ? "+" : "-"));
		presentInside.push(has(type));
	}

	override private function listenerThrew(error:haxe.Exception, event:Event):Void {
		thrown.push(error.message + "@" + event.type);
		if (throwFromHook) {
			throw new haxe.Exception("hook");
		}
	}

	public function log():String {
		return changes.join(",");
	}
}

/** An event carrying a value, for typed listeners. **/
class ValueEvent extends Event {
	public static inline var VALUE:EventType<ValueEvent> = "value";

	public var value:Int;

	public function new(type:String, value:Int, bubbles:Bool = false) {
		super(type, bubbles);
		this.value = value;
	}

	override public function clone():Event {
		var copy = new ValueEvent(type, value, bubbles);
		return copy;
	}
}

/**
	Something that holds an emitter and hands its calls on: a delegate
	target. It offers `on`, `off` and `has` of its own, as such a class does.
**/
class Holder implements IEmitter {
	public var emitter:Emitter;

	public function new() {
		emitter = new Emitter(this);
	}

	public inline function on<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Subscription {
		return emitter.on(type, listener, priority);
	}

	public inline function off<T:Event>(type:EventType<T>, listener:T->Void):Void {
		emitter.off(type, listener);
	}

	public inline function has<T:Event>(type:EventType<T>, ?listener:T->Void):Bool {
		return emitter.has(type, listener);
	}

	public function dispatch(event:Event):Bool {
		return emitter.dispatch(event);
	}
}

/**
	A framework's dispatcher, as the README shows one: ActionScript's names,
	each a one-line inline method on the framework's own subclass, so the
	framework's call sites compile unchanged.
**/
class FlashDispatcher extends Emitter {
	public function new() {
		super();
	}

	public inline function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void {
		on(type, listener, priority);
	}

	public inline function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void {
		off(type, listener);
	}

	public inline function hasEventListener(type:String):Bool {
		return has(type);
	}

	public inline function dispatchEvent(event:Event):Bool {
		return dispatch(event);
	}

	public inline function removeEventListeners(?type:String):Void {
		if (type == null) {
			clear();
		} else {
			clear(type);
		}
	}
}

/** Reads internals the tests check: how many walks a lane counts. **/
@:access(emitter.Emitter)
class Inside {
	public static function eventWalks(emitter:Emitter):Int {
		var lane = emitter.__events;
		return lane == null ? 0 : lane.walking;
	}

	public static function signalWalks(emitter:Emitter):Int {
		var lane = emitter.__signals;
		return lane == null ? 0 : lane.walking;
	}

	public static function idle(emitter:Emitter):Bool {
		return emitter.__events == null && emitter.__signals == null;
	}

	public static function hasEventLane(emitter:Emitter):Bool {
		return emitter.__events != null;
	}

	public static function hasSignalLane(emitter:Emitter):Bool {
		return emitter.__signals != null;
	}
}
