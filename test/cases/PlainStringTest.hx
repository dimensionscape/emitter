package cases;

import emitter.Emitter;
import emitter.Event;
import haxe.Constraints.Function;
import utest.Assert;
import utest.Test;

/**
	Signals named by a plain string, as Emitter 1 had them: a listener of any
	type, or an untyped `Function`, makes the string a signal; a listener
	taking an `Event` makes it an event type.
**/
class PlainStringTest extends Test {
	function testAnUntypedFunctionListensToAStringSignal() {
		var emitter = new Emitter();
		var heard:Dynamic = null;
		var callback:Function = function(data:Dynamic) heard = data;
		emitter.events.on("test", callback);
		Assert.isTrue(emitter.events.emit("test", 42));
		Assert.equals(42, heard);
		emitter.events.off("test", callback);
		Assert.isFalse(emitter.events.emit("test", 43));
		Assert.equals(42, heard);
	}

	function testATypedLambdaListensToAStringSignal() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on("none", () -> log.push("0"));
		emitter.events.on("one", (n:Int) -> log.push("1:" + n));
		emitter.events.on("two", (a:Int, b:String) -> log.push('2:$a$b'));
		emitter.events.on("five", (a:Int, b:Int, c:Int, d:Int, e:Int) -> log.push('5:${a + b + c + d + e}'));
		emitter.events.emit("none");
		emitter.events.emit("one", 1);
		emitter.events.emit("two", 2, "x");
		emitter.events.emit("five", 1, 2, 3, 4, 5);
		Assert.equals("0,1:1,2:2x,5:15", log.join(","));
	}

	function testAStringWithAnEventListenerIsAnEventType() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on("ready", (event:Event) -> log.push("event " + event.type));
		Assert.isTrue(emitter.events.dispatch(new Event("ready")));
		Assert.isFalse(emitter.events.emit("ready"));
		Assert.isTrue(emitter.events.has("ready"));
		Assert.equals("event ready", log.join(","));
	}

	function testOneNameCanBeAnEventAndASignalApart() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on("ready", (event:Event) -> log.push("event"));
		emitter.events.on("ready", (n:Int) -> log.push("signal " + n));
		emitter.events.dispatch(new Event("ready"));
		emitter.events.emit("ready", 3);
		Assert.equals("event,signal 3", log.join(","));
		emitter.events.clear("ready");
		emitter.events.dispatch(new Event("ready"));
		emitter.events.emit("ready", 4);
		Assert.equals("event,signal 3,signal 4", log.join(","));
	}

	function testOnceAndASubscriptionWorkWithAStringSignal() {
		var emitter = new Emitter();
		var count = 0;
		emitter.events.once("tick", (n:Int) -> count += n);
		emitter.events.emit("tick", 2);
		emitter.events.emit("tick", 2);
		Assert.equals(2, count);
		var sub = emitter.events.on("tick", (n:Int) -> count += n);
		sub.cancel();
		Assert.isFalse(emitter.events.emit("tick", 5));
		Assert.equals(2, count);
	}
}
