package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.IEmitter;
import support.Support;
import support.TypeCheck;
import utest.Assert;
import utest.Test;

/**
	An event's `target` and `currentTarget` taken as the class they are,
	without a cast: `var node:Node = event.target`. Anything that is not an
	emitter does not compile.
**/
class EventTargetTest extends Test {
	function testATargetIsTakenAsTheClassItIs() {
		var node = new Node("leaf");
		var event = new Event(Event.CHANGE);
		node.events.dispatch(event);

		var taken:Node = event.target;
		Assert.equals(node, taken);
		Assert.equals("leaf", taken.name);

		var emitter:Emitter = event.target;
		Assert.equals((node : Emitter), emitter);

		var asInterface:IEmitter = event.target;
		Assert.equals((node : IEmitter), asInterface);
	}

	function testAThingThatIsNoEmitterDoesNotCompile() {
		var event = new Event(Event.CHANGE);
		var error:Null<String> = TypeCheck.errorOf({
			var other:NotAnEmitter = event.target;
		});
		Assert.notNull(error, "a target compiled as a class that is no emitter");
		Assert.stringContains("NotAnEmitter", error == null ? "" : error);

		// The same three lines as above, checked the same way, compile.
		Assert.isNull(TypeCheck.errorOf({
			var taken:Node = event.target;
		}));
		Assert.isNull(TypeCheck.errorOf({
			var emitter:Emitter = event.target;
		}));
		Assert.isNull(TypeCheck.errorOf({
			var asInterface:IEmitter = event.target;
		}));
	}

	function testACurrentTargetIsTakenAsTheClassItIsWhileItBubbles() {
		var root = new Node("root");
		var leaf = new Node("leaf", root);
		var seen:Array<String> = [];
		root.events.on(Event.CHANGE, function(event:Event):Void {
			var current:Node = event.currentTarget;
			var target:Node = event.target;
			seen.push(current.name + "<" + target.name);
		});
		leaf.events.dispatch(new Event(Event.CHANGE, true));
		Assert.equals("root<leaf", seen.join(","));
	}

	function testADelegateTargetIsTakenAsTheClassThatHoldsTheEmitter() {
		var holder = new Holder();
		var taken:Null<Holder> = null;
		holder.events.on(Event.CHANGE, function(event:Event):Void {
			taken = event.target;
		});
		holder.events.dispatch(new Event(Event.CHANGE));
		Assert.equals(holder, taken);
	}

	function testATargetsVerbsAreReachedThroughIt() {
		var node = new Node("leaf");
		var heard:Array<String> = [];
		node.events.on("pong", function(event:Event):Void {
			heard.push(event.type);
		});
		node.events.on("ping", function(event:Event):Void {
			event.target.events.dispatch(new Event("pong"));
		});
		node.events.dispatch(new Event("ping"));
		Assert.equals("pong", heard.join(","));
	}

	function testATargetIsStillChecked() {
		var node = new Node("leaf");
		var event = new Event(Event.CHANGE);
		node.events.dispatch(event);
		Assert.isTrue(Std.isOfType(event.target, Node));
		Assert.isFalse(Std.isOfType(event.target, Holder));
		Assert.equals(node, Std.downcast(event.target, Node));
		Assert.isNull(Std.downcast(event.target, Recording));
	}
}

/** Not an emitter: no target is one. **/
private class NotAnEmitter {
	public function new() {}
}
