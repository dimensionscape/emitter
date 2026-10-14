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
		emitter.on(PING, a);
		emitter.on(PING, b);
		emitter.off(PING, a);
		emitter.off(PING, a);
		emitter.off(PING, b);
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testAnIgnoredDuplicateIsNotAChange() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.on(PING, a);
		emitter.on(PING, a);
		emitter.on(PING, a, 9);
		emitter.once(PING, a);
		Assert.equals("ping+", emitter.log());
	}

	function testOnceAndAPriorityReportTheFirstListener() {
		var emitter = new Recording();
		emitter.on(PING, function(_) {}, 3);
		emitter.once(PONG, function(_) {});
		Assert.equals("ping+,pong+", emitter.log());
	}

	function testCancellingTheLastSubscriptionReportsTheLast() {
		var emitter = new Recording();
		var a = emitter.on(PING, function(_) {});
		var b = emitter.once(PING, function(_) {});
		a.cancel();
		Assert.equals("ping+", emitter.log());
		b.cancel();
		b.cancel();
		Assert.equals("ping+,ping-", emitter.log());
	}

	function testAOnceListenerBeingCalledReportsTheLast() {
		var emitter = new Recording();
		emitter.once(PING, function(_) {});
		emitter.dispatch(new Event(PING));
		Assert.equals("ping+,ping-", emitter.log());

		var many = new Recording();
		many.once(PING, function(_) {});
		many.once(PING, function(_) {});
		many.dispatch(new Event(PING));
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
		emitter.clear(PING);
		emitter.clear(PING);
		Assert.equals("ping+,pong+,ping-", emitter.log());

		emitter.on("third", function(_:Event) {});
		emitter.changes = [];
		emitter.clear();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("pong-,third-", reported.join(","));
	}

	function testRemoveAllListenersReportsEveryEventType() {
		var emitter = new Recording();
		emitter.on(PING, function(_) {});
		emitter.on(PONG, function(_) {});
		emitter.changes = [];
		emitter.clear();
		var reported = emitter.changes.copy();
		reported.sort(Reflect.compare);
		Assert.equals("ping-,pong-", reported.join(","));
		emitter.changes = [];
		emitter.clear();
		Assert.equals("", emitter.log());
	}

	function testTheHookSeesTheChangeAlreadyMade() {
		var emitter = new Recording();
		var a = function(_:Event) {};
		emitter.on(PING, a);
		emitter.off(PING, a);
		emitter.once(PONG, function(_) {});
		emitter.dispatch(new Event(PONG));
		Assert.equals("true,false,true,false", emitter.presentInside.join(","));
	}

	function testTheHookIsTheSameForManyTypes() {
		// Past the chain into the map, the same reports.
		var emitter = new Recording();
		for (i in 0...12) {
			emitter.on("t" + i, function(_:Event) {});
		}
		for (i in 0...12) {
			emitter.clear("t" + i);
		}
		Assert.equals(24, emitter.changes.length);
		Assert.equals("t11-", emitter.changes[23]);
	}

	function testAHookMayAddListenersWhileEverythingIsRemoved() {
		var emitter = new Rearming();
		emitter.on(PING, function(_) {});
		emitter.clear();
		Assert.isTrue(emitter.has(PONG));
		Assert.isFalse(emitter.has(PING));
	}

	function testListenersChangedDuringADispatchAreReportedAtOnce() {
		var emitter = new Recording();
		var b = function(_:Event) {};
		emitter.on(PING, function(_) {
			emitter.off(PING, b);
			emitter.on(PONG, b);
			emitter.clear(PING);
		});
		emitter.on(PING, b);
		emitter.changes = [];
		emitter.dispatch(new Event(PING));
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
			on("pong", function(_:Event) {});
		}
	}
}
