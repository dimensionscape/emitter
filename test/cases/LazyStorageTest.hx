package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal1;
import support.Support;
import utest.Assert;
import utest.Test;

/** Nothing held until something listens; no constructor needed. **/
class LazyStorageTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var VALUE:Signal1<Int> = "value";

	function testANewEmitterHoldsNothing() {
		var emitter = new Emitter();
		Assert.isTrue(Inside.idle(emitter));
	}

	function testAskingDispatchingAndRemovingHoldNothingEither() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.events.has(PING));
		Assert.isFalse(emitter.events.has(VALUE));
		Assert.isFalse(emitter.events.dispatch(new Event(PING, true)));
		Assert.isFalse(emitter.dispatchLocal(new Event(PING)));
		Assert.isFalse(emitter.dispatchContained(new Event(PING)));
		Assert.isFalse(emitter.events.emit(VALUE, 1));
		emitter.events.off(PING, function(_) {});
		emitter.events.off(VALUE, function(_) {});
		emitter.events.clear();
		Assert.isFalse(emitter.allowDuplicates);
		Assert.isTrue(Inside.idle(emitter));
	}

	function testEachLaneIsMadeByItsFirstListener() {
		var emitter = new Emitter();
		emitter.events.on(VALUE, function(_) {});
		Assert.isFalse(Inside.hasEventLane(emitter));
		Assert.isTrue(Inside.hasSignalLane(emitter));
		emitter.events.on(PING, function(_) {});
		Assert.isTrue(Inside.hasEventLane(emitter));
	}

	function testRemovingEverythingGoesBackToHoldingNothing() {
		var emitter = new Emitter();
		emitter.events.on(VALUE, function(_) {});
		emitter.events.on(PING, function(_) {});
		emitter.events.clear();
		Assert.isTrue(Inside.idle(emitter));
	}

	function testADelegateOrAPolicyKeepsTheEventLane() {
		var holder = new Holder();
		holder.emitter.events.clear();
		Assert.isTrue(Inside.hasEventLane(holder.emitter));
		var seen = null;
		holder.events.on(PING, function(e:Event) seen = e.target);
		holder.events.dispatch(new Event(PING));
		Assert.equals((holder : emitter.IEmitter), seen);

		var keeping = new Emitter();
		keeping.allowDuplicates = true;
		keeping.events.on(PING, function(_) {});
		keeping.events.clear();
		Assert.isTrue(keeping.allowDuplicates);
	}

	function testAnEmitterMadeWithoutItsConstructorWorks() {
		var emitter:Emitter = Type.createEmptyInstance(Emitter);
		exercise(emitter);
	}

	function testASubclassMadeWithoutItsConstructorWorks() {
		var node:BareNode = Type.createEmptyInstance(BareNode);
		exercise(node);
		var parent:BareNode = Type.createEmptyInstance(BareNode);
		node.parent = parent;
		var heard = false;
		parent.events.on(PING, function(_) heard = true);
		node.events.dispatch(new Event(PING, true));
		Assert.isTrue(heard);
	}

	function exercise(emitter:Emitter) {
		Assert.isFalse(emitter.events.has(PING));
		Assert.isFalse(emitter.allowDuplicates);
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		Assert.isFalse(emitter.events.emit(VALUE, 1));
		var log = [];
		var listener = function(_:Event) log.push("event");
		emitter.events.on(PING, listener);
		emitter.events.on(PING, listener);
		emitter.events.once(PING, function(_) log.push("once"));
		emitter.events.on(VALUE, function(v) log.push("signal" + v));
		Assert.isTrue(emitter.events.dispatch(new Event(PING)));
		Assert.isTrue(emitter.events.dispatch(new Event(PING)));
		Assert.isTrue(emitter.events.emit(VALUE, 3));
		Assert.equals("event,once,event,signal3", log.join(","));
		emitter.events.clear();
		Assert.isFalse(emitter.events.has(PING));
		emitter.allowDuplicates = true;
		Assert.isTrue(emitter.allowDuplicates);
	}
}
