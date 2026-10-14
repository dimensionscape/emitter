package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal1;
import support.Support;
import utest.Assert;
import utest.Test;

/** Listeners added and removed while a dispatch is running. **/
class MidDispatchTest extends Test {
	static inline var PING:EventType<Event> = "ping";

	function testAListenerRemovedDuringADispatchStillRunsForIt() {
		var emitter = new Emitter();
		var log = [];
		var b = function(_:Event) log.push("b");
		emitter.events.on(PING, function(_) {
			log.push("a");
			emitter.events.off(PING, b);
		});
		emitter.events.on(PING, b);
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b", log.join(","));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b,a", log.join(","));
	}

	function testAListenerAddedDuringADispatchWaitsForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var added = false;
		emitter.events.on(PING, function(_) {
			log.push("a");
			if (!added) {
				added = true;
				emitter.events.on(PING, function(_) log.push("late"));
			}
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b", log.join(","));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b,a,b,late", log.join(","));
	}

	function testAListenerAddedByTheOnlyListenerWaitsForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var added = false;
		emitter.events.on(PING, function(_) {
			log.push("a");
			if (!added) {
				added = true;
				emitter.events.on(PING, function(_) log.push("first"), 1);
			}
		});
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,first,a", log.join(","));
	}

	function testAListenerMayRemoveItself() {
		var emitter = new Emitter();
		var calls = 0;
		var self:Event->Void = null;
		self = function(_:Event) {
			calls++;
			emitter.events.off(PING, self);
		};
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PING, self);
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
		Assert.isFalse(emitter.events.has(PING, self));
	}

	function testAListenerMayRemoveAndAddItselfAgain() {
		var emitter = new Emitter();
		var log = [];
		var self:Event->Void = null;
		self = function(_:Event) {
			log.push("self");
			emitter.events.off(PING, self);
			emitter.events.on(PING, self);
		};
		emitter.events.on(PING, self);
		emitter.events.on(PING, function(_) log.push("other"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("self,other", log.join(","));
		// Added again, it went to the end.
		emitter.events.dispatch(new Event(PING));
		Assert.equals("self,other,other,self", log.join(","));
		Assert.isTrue(emitter.events.has(PING, self));
	}

	function testHasEventListenerIsExactDuringADispatch() {
		var emitter = new Emitter();
		var answers = [];
		var b = function(_:Event) {};
		emitter.events.on(PING, function(_) {
			answers.push(emitter.events.has(PING, b));
			emitter.events.off(PING, b);
			answers.push(emitter.events.has(PING, b));
			answers.push(emitter.events.has(PING));
			emitter.events.clear(PING);
			answers.push(emitter.events.has(PING));
			emitter.events.on("other", b);
			answers.push(emitter.events.has("other"));
		});
		emitter.events.on(PING, b);
		emitter.events.dispatch(new Event(PING));
		Assert.equals("true,false,true,false,true", answers.join(","));
	}

	function testRemovingEverythingDuringADispatchLetsItFinish() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) {
			log.push("a");
			emitter.events.clear();
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.dispatch(new Event(PING));
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		Assert.equals("a,b", log.join(","));
	}

	function testANestedDispatchSeesTheListenersAsTheyAreThen() {
		var emitter = new Emitter();
		var log = [];
		var depth = 0;
		var c = function(_:Event) log.push("c" + depth);
		emitter.events.on(PING, function(e:Event) {
			log.push("a" + depth);
			if (depth == 0) {
				depth++;
				emitter.events.off(PING, c);
				emitter.events.dispatch(new Event(PING));
				depth--;
			}
		});
		emitter.events.on(PING, function(_) log.push("b" + depth));
		emitter.events.on(PING, c);
		emitter.events.dispatch(new Event(PING));
		// The nested dispatch no longer has c; the outer one still does.
		Assert.equals("a0,a1,b1,b0,c0", log.join(","));
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testAOnceListenerRunsOnceEvenWhenANestedDispatchReachesItFirst() {
		var emitter = new Emitter();
		var onceCalls = 0;
		var nested = false;
		emitter.events.on(PING, function(_) {
			if (!nested) {
				nested = true;
				emitter.events.dispatch(new Event(PING));
			}
		});
		emitter.events.once(PING, function(_) onceCalls++);
		var lastCalls = 0;
		emitter.events.on(PING, function(_) lastCalls++);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, onceCalls);
		// The outer dispatch passes over the spent once to the listener after it.
		Assert.equals(2, lastCalls);
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testAOnceListenerCancelledDuringTheDispatchStillRunsForIt() {
		// The same rule as any other listener removed during a dispatch.
		var emitter = new Emitter();
		var calls = 0;
		var pending = function(_:Event) calls++;
		emitter.events.on(PING, function(_) emitter.events.off(PING, pending));
		emitter.events.once(PING, pending);
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testOnceListenersRunOnceEachWhereverTheyStand() {
		// A once comes out of the list being walked where it stands: every
		// listener after it must still run, exactly once.
		for (shape in ["o,a,b", "a,o,b", "a,b,o", "o,o,a", "a,o,o", "o,o,o", "o"]) {
			var emitter = new Emitter();
			var log = [];
			var parts = shape.split(",");
			for (i in 0...parts.length) {
				var name = parts[i] + i;
				if (parts[i] == "o") {
					emitter.events.once(PING, function(_) log.push(name));
				} else {
					emitter.events.on(PING, function(_) log.push(name));
				}
			}
			emitter.events.dispatch(new Event(PING));
			var first = log.join(",");
			log = [];
			emitter.events.dispatch(new Event(PING));
			var expected = [for (i in 0...parts.length) parts[i] + i];
			Assert.equals(expected.join(","), first, shape);
			Assert.equals([for (name in expected) if (name.charAt(0) != "o") name].join(","), log.join(","), shape);
		}
	}

	function testAOnceThatChangesItsListWhileRunningLeavesTheWalkWhole() {
		var emitter = new Emitter();
		var log = [];
		var c = function(_:Event) log.push("c");
		var added = function(_:Event) log.push("added");
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.once(PING, function(_) {
			log.push("once");
			emitter.events.off(PING, c);
			emitter.events.on(PING, added);
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.on(PING, c);
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,once,b,c", log.join(","));
		log = [];
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b,added", log.join(","));
	}

	function testAOnceThatStopsTheEventComesOutAndStopsIt() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.once(PING, function(e:Event) {
			log.push("once");
			e.stopImmediatePropagation();
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("once,b", log.join(","));
	}

	function testOnceSignalListenersRunOnceEachWhereverTheyStand() {
		var VALUE:Signal1<Int> = "value";
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(VALUE, function(v) log.push("a" + v));
		emitter.events.once(VALUE, function(v) log.push("o" + v));
		emitter.events.on(VALUE, function(v) log.push("b" + v));
		emitter.events.once(VALUE, function(v) log.push("p" + v));
		emitter.events.emit(VALUE, 1);
		emitter.events.emit(VALUE, 2);
		Assert.equals("a1,o1,b1,p1,a2,b2", log.join(","));
		Assert.equals(0, Inside.signalWalks(emitter));
	}

	function testListsChangedDuringADispatchKeepTheirOrder() {
		var emitter = new Emitter();
		var log = [];
		var once = true;
		emitter.events.on(PING, function(_) {
			log.push("a");
			if (once) {
				once = false;
				emitter.events.on(PING, function(_) log.push("high"), 10);
				emitter.events.on(PING, function(_) log.push("low"), -10);
			}
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b", log.join(","));
		log = [];
		emitter.events.dispatch(new Event(PING));
		Assert.equals("high,a,b,low", log.join(","));
	}
}
