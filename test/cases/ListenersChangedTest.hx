package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import support.Support;
import utest.Assert;
import utest.Test;

/** The listenersChanged hook, from every path that adds or removes. **/
class ListenersChangedTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";

	function testTheFirstAddAndTheLastRemovalAreReported() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		var b = function(_:Event) {};
		emitter.addEventListener(PING, a);
		emitter.addEventListener(PING, b);
		emitter.removeEventListener(PING, a);
		emitter.removeEventListener(PING, a);
		emitter.removeEventListener(PING, b);
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testAnIgnoredDuplicateIsNotAChange() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.on(PING, a);
		emitter.on(PING, a);
		emitter.prepend(PING, a);
		emitter.once(PING, a);
		Assert.equals("ping+", emitter.log());
	}

	function testPrependAndOnceReportTheFirstListener() {
		var emitter = new Recording();
		emitter.prepend(PING, function(_) {});
		emitter.once(PONG, function(_) {});
		Assert.equals("ping+,pong+", emitter.log());
	}

	function testAOnceListenerBeingCalledReportsTheLast() {
		var emitter = new Recording();
		emitter.once(PING, function(_) {});
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("ping+,ping-", emitter.log());

		var many = new Recording();
		many.once(PING, function(_) {});
		many.once(PING, function(_) {});
		many.dispatchEvent(new Event(PING));
		Assert.equals("ping+,ping-", many.log());
	}

	function testCancellingTheOnlyOnceReportsTheLast() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.once(PING, a);
		emitter.off(PING, a);
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testRemovingATypeOrAllReportsEachType() {
		var emitter = new Recording();
		emitter.on(PING, function(_) {});
		emitter.on(PING, function(_) {});
		emitter.on(PONG, function(_) {});
		emitter.removeEventListeners(PING);
		emitter.removeEventListeners(PING);
		Assert.equals("ping+,pong+,ping-", emitter.log());

		emitter.addEventListener("third", function(_:Event) {});
		emitter.changes = [];
		emitter.removeEventListeners();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("pong-,third-", reported.join(","));
	}

	function testRemoveAllListenersReportsEveryEventType() {
		var emitter = new Recording();
		emitter.on(PING, function(_) {});
		emitter.on(PONG, function(_) {});
		emitter.changes = [];
		emitter.removeAllListeners();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("ping-,pong-", reported.join(","));
		emitter.changes = [];
		emitter.removeAllListeners();
		Assert.equals("", emitter.log());
	}

	function testTheHookSeesTheChangeAlreadyMade() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.on(PING, a);
		emitter.off(PING, a);
		emitter.once(PONG, function(_) {});
		emitter.dispatchEvent(new Event(PONG));
		Assert.equals("true,false,true,false", emitter.presentInside.join(","));
	}

	function testTheHookIsTheSameForManyTypes() {
		// Past the chain into the map, the same reports.
		var emitter = new Recording();
		for (i in 0...12) {
			emitter.addEventListener("t" + i, function(_:Event) {});
		}
		for (i in 0...12) {
			emitter.removeEventListeners("t" + i);
		}
		Assert.equals(24, emitter.changes.length);
		Assert.equals("t11-", emitter.changes[23]);
	}

	function testAHookMayAddListenersWhileEverythingIsRemoved() {
		var emitter = new Rearming();
		emitter.on(PING, function(_) {});
		emitter.removeEventListeners();
		Assert.isTrue(emitter.hasEventListener(PONG));
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	function testListenersChangedDuringADispatchAreReportedAtOnce() {
		var emitter = new Recording();
		var b = function(_:Event) {};
		emitter.on(PING, function(_) {
			emitter.off(PING, b);
			emitter.on(PONG, b);
			emitter.removeEventListeners(PING);
		});
		emitter.on(PING, b);
		emitter.changes = [];
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("pong+,ping-", emitter.log());
	}
}

/** Adds a PONG listener when it hears PING has lost its last. **/
private class Rearming extends Emitter {
	public function new() {
		super();
	}

	override private function listenersChanged(type:String, present:Bool):Void {
		if (type == "ping" && !present) {
			addEventListener("pong", function(_:Event) {});
		}
	}
}
