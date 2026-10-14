package support;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;

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
		presentInside.push(hasEventListener(type));
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

/** Something that holds an emitter and hands its calls on: a delegate target. **/
class Holder implements IEmitter {
	public var emitter:Emitter;

	public function new() {
		emitter = new Emitter(this);
	}

	public function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void {
		emitter.addEventListener(type, listener, priority);
	}

	public function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void {
		emitter.removeEventListener(type, listener);
	}

	public function hasEventListener(type:String):Bool {
		return emitter.hasEventListener(type);
	}

	public function dispatchEvent(event:Event):Bool {
		return emitter.dispatchEvent(event);
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
