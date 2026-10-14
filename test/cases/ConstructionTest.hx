package cases;

import emitter.Emitter;
import emitter.Event;
import utest.Assert;
import utest.Test;

/**
	Emitters made through constructors a framework's classes chain. On the
	jvm a class with a dynamic method is built in two steps, and so must be
	every class above it; a class between it and `Emitter` with a plain
	constructor once left one step missing, and the class failed the jvm's
	verifier as it loaded.
**/
class ConstructionTest extends Test {
	function testASubclassWithADynamicMethodBelowAnotherIsMade() {
		var made = new Hooked(3);
		Assert.equals(3, made.depth);
		Assert.equals(7, made.hook());
		var heard:Array<String> = [];
		made.events.on("ping", function(event:Event):Void {
			heard.push(event.type);
		});
		Assert.isTrue(made.events.dispatch(new Event("ping")));
		Assert.equals("ping", heard.join(","));

		made.hook = () -> 9;
		Assert.equals(9, made.hook());
	}

	function testASubclassKeepsTheVerbsNamesForItsOwnMembers() {
		// The verbs are reached through `events`, so a framework's class may
		// have a `clear`, a `has`, a `dispatch` of its own (a shape's clear,
		// a framework's dispatch by type and data) beside them.
		var canvas = new Canvas();
		var heard:Array<String> = [];
		canvas.events.on("ping", function(event:Event):Void {
			heard.push(event.type);
		});
		canvas.dispatch("ping");
		canvas.clear();
		Assert.equals("ping", heard.join(","));
		Assert.equals(1, canvas.cleared);
		Assert.isTrue(canvas.events.has("ping"));
		Assert.isFalse(canvas.has(3));
		canvas.on(2);
		Assert.isTrue(canvas.has(2));
		Assert.equals(1, canvas.emit());
		canvas.events.clear();
		Assert.isFalse(canvas.events.has("ping"));
		Assert.isFalse(canvas.events.dispatch(new Event("ping")));
	}

	function testADelegateTargetIsKeptThroughTheChain() {
		var holder = new Hooked(1);
		var inner = new Middle(holder);
		var seen:Array<Bool> = [];
		inner.events.on("ping", function(event:Event):Void {
			seen.push(event.target == holder);
		});
		inner.events.dispatch(new Event("ping"));
		Assert.equals("true", seen.join(","));
	}
}

/** A plain constructor between `Emitter` and a class built in two steps. **/
private class Middle extends Emitter {
	public var depth:Int;

	public function new(?target:Emitter, depth:Int = 0) {
		super(target);
		this.depth = depth;
	}
}

/** A dynamic method: on the jvm, built in two steps. **/
private class Hooked extends Middle {
	public function new(depth:Int) {
		super(null, depth);
	}

	public dynamic function hook():Int {
		return 7;
	}
}

/** A class with members of its own named as the verbs are. **/
private class Canvas extends Emitter {
	public var cleared:Int = 0;

	var marks:Array<Int> = [];

	public function new() {
		super();
	}

	public function clear():Void {
		cleared++;
	}

	public function has(mark:Int):Bool {
		return marks.indexOf(mark) >= 0;
	}

	public function on(mark:Int):Void {
		marks.push(mark);
	}

	public function emit():Int {
		return marks.length;
	}

	public function dispatch(type:String):Bool {
		return events.dispatch(new Event(type));
	}
}
