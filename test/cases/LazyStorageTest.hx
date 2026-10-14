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
		Assert.isFalse(emitter.has(PING));
		Assert.isFalse(emitter.has(VALUE));
		Assert.isFalse(emitter.dispatch(new Event(PING, true)));
		Assert.isFalse(emitter.dispatchLocal(new Event(PING)));
		Assert.isFalse(emitter.dispatchContained(new Event(PING)));
		Assert.isFalse(emitter.emit(VALUE, 1));
		emitter.off(PING, function(_) {});
		emitter.off(VALUE, function(_) {});
		emitter.clear();
		Assert.isFalse(emitter.allowDuplicates);
		Assert.isTrue(Inside.idle(emitter));
	}

	function testEachLaneIsMadeByItsFirstListener() {
		var emitter = new Emitter();
		emitter.on(VALUE, function(_) {});
		Assert.isFalse(Inside.hasEventLane(emitter));
		Assert.isTrue(Inside.hasSignalLane(emitter));
		emitter.on(PING, function(_) {});
		Assert.isTrue(Inside.hasEventLane(emitter));
	}

	function testRemovingEverythingGoesBackToHoldingNothing() {
		var emitter = new Emitter();
		emitter.on(VALUE, function(_) {});
		emitter.on(PING, function(_) {});
		emitter.clear();
		Assert.isTrue(Inside.idle(emitter));
	}

	function testADelegateOrAPolicyKeepsTheEventLane() {
		var holder = new Holder();
		holder.emitter.clear();
		Assert.isTrue(Inside.hasEventLane(holder.emitter));
		var seen = null;
		holder.on(PING, function(e:Event) seen = e.target);
		holder.dispatch(new Event(PING));
		Assert.equals((holder : emitter.IEmitter), seen);

		var keeping = new Emitter();
		keeping.allowDuplicates = true;
		keeping.on(PING, function(_) {});
		keeping.clear();
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
		parent.on(PING, function(_) heard = true);
		node.dispatch(new Event(PING, true));
		Assert.isTrue(heard);
	}

	function exercise(emitter:Emitter) {
		Assert.isFalse(emitter.has(PING));
		Assert.isFalse(emitter.allowDuplicates);
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.isFalse(emitter.emit(VALUE, 1));
		var log = [];
		var listener = function(_:Event) log.push("event");
		emitter.on(PING, listener);
		emitter.on(PING, listener);
		emitter.once(PING, function(_) log.push("once"));
		emitter.on(VALUE, function(v) log.push("signal" + v));
		Assert.isTrue(emitter.dispatch(new Event(PING)));
		Assert.isTrue(emitter.dispatch(new Event(PING)));
		Assert.isTrue(emitter.emit(VALUE, 3));
		Assert.equals("event,once,event,signal3", log.join(","));
		emitter.clear();
		Assert.isFalse(emitter.has(PING));
		emitter.allowDuplicates = true;
		Assert.isTrue(emitter.allowDuplicates);
	}
}
