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
		emitter.events.on(PING, a);
		emitter.events.on(PING, b);
		emitter.events.off(PING, a);
		emitter.events.off(PING, a);
		emitter.events.off(PING, b);
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testAnIgnoredDuplicateIsNotAChange() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.events.on(PING, a);
		emitter.events.on(PING, a);
		emitter.events.on(PING, a, 9);
		emitter.events.once(PING, a);
		Assert.equals("ping+", emitter.log());
	}

	function testOnceAndAPriorityReportTheFirstListener() {
		var emitter = new Recording();
		emitter.events.on(PING, function(_) {}, 3);
		emitter.events.once(PONG, function(_) {});
		Assert.equals("ping+,pong+", emitter.log());
	}

	function testCancellingTheLastSubscriptionReportsTheLast() {
		var emitter = new Recording();
		var a = emitter.events.on(PING, function(_) {});
		var b = emitter.events.once(PING, function(_) {});
		a.cancel();
		Assert.equals("ping+", emitter.log());
		b.cancel();
		b.cancel();
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testAOnceListenerBeingCalledReportsTheLast() {
		var emitter = new Recording();
		emitter.events.once(PING, function(_) {});
		emitter.events.dispatch(new Event(PING));
		Assert.equals("ping+,ping-", emitter.log());

		var many = new Recording();
		many.events.once(PING, function(_) {});
		many.events.once(PING, function(_) {});
		many.events.dispatch(new Event(PING));
		Assert.equals("ping+,ping-", many.log());
	}

	function testCancellingTheOnlyOnceReportsTheLast() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.events.once(PING, a);
		emitter.events.off(PING, a);
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testRemovingATypeOrAllReportsEachType() {
		var emitter = new Recording();
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PONG, function(_) {});
		emitter.events.clear(PING);
		emitter.events.clear(PING);
		Assert.equals("ping+,pong+,ping-", emitter.log());

		emitter.events.on("third", function(_:Event) {});
		emitter.changes = [];
		emitter.events.clear();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("pong-,third-", reported.join(","));
	}

	function testRemoveAllListenersReportsEveryEventType() {
		var emitter = new Recording();
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PONG, function(_) {});
		emitter.changes = [];
		emitter.events.clear();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("ping-,pong-", reported.join(","));
		emitter.changes = [];
		emitter.events.clear();
		Assert.equals("", emitter.log());
	}

	function testTheHookSeesTheChangeAlreadyMade() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.events.on(PING, a);
		emitter.events.off(PING, a);
		emitter.events.once(PONG, function(_) {});
		emitter.events.dispatch(new Event(PONG));
		Assert.equals("true,false,true,false", emitter.presentInside.join(","));
	}

	function testTheHookIsTheSameForManyTypes() {
		// Past the chain into the map, the same reports.
		var emitter = new Recording();
		for (i in 0...12) {
			emitter.events.on("t" + i, function(_:Event) {});
		}
		for (i in 0...12) {
			emitter.events.clear("t" + i);
		}
		Assert.equals(24, emitter.changes.length);
		Assert.equals("t11-", emitter.changes[23]);
	}

	function testAHookMayAddListenersWhileEverythingIsRemoved() {
		var emitter = new Rearming();
		emitter.events.on(PING, function(_) {});
		emitter.events.clear();
		Assert.isTrue(emitter.events.has(PONG));
		Assert.isFalse(emitter.events.has(PING));
	}

	function testListenersChangedDuringADispatchAreReportedAtOnce() {
		var emitter = new Recording();
		var b = function(_:Event) {};
		emitter.events.on(PING, function(_) {
			emitter.events.off(PING, b);
			emitter.events.on(PONG, b);
			emitter.events.clear(PING);
		});
		emitter.events.on(PING, b);
		emitter.changes = [];
		emitter.events.dispatch(new Event(PING));
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
			events.on("pong", function(_:Event) {});
		}
	}
}
