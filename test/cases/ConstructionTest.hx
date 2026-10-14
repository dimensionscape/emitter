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
		made.on("ping", function(event:Event):Void {
			heard.push(event.type);
		});
		Assert.isTrue(made.dispatch(new Event("ping")));
		Assert.equals("ping", heard.join(","));

		made.hook = () -> 9;
		Assert.equals(9, made.hook());
	}

	function testADelegateTargetIsKeptThroughTheChain() {
		var holder = new Hooked(1);
		var inner = new Middle(holder);
		var seen:Array<Bool> = [];
		inner.on("ping", function(event:Event):Void {
			seen.push(event.target == holder);
		});
		inner.dispatch(new Event("ping"));
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
