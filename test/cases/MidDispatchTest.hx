package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
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
		emitter.on(PING, function(_) {
			log.push("a");
			emitter.off(PING, b);
		});
		emitter.on(PING, b);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,b", log.join(","));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,b,a", log.join(","));
	}

	function testAListenerAddedDuringADispatchWaitsForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var added = false;
		emitter.on(PING, function(_) {
			log.push("a");
			if (!added) {
				added = true;
				emitter.on(PING, function(_) log.push("late"));
			}
		});
		emitter.on(PING, function(_) log.push("b"));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,b", log.join(","));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,b,a,b,late", log.join(","));
	}

	function testAListenerAddedByTheOnlyListenerWaitsForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var added = false;
		emitter.on(PING, function(_) {
			log.push("a");
			if (!added) {
				added = true;
				emitter.prepend(PING, function(_) log.push("first"));
			}
		});
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,first,a", log.join(","));
	}

	function testAListenerMayRemoveItself() {
		var emitter = new Emitter();
		var calls = 0;
		var self:Event->Void = null;
		self = function(_:Event) {
			calls++;
			emitter.off(PING, self);
		};
		emitter.on(PING, function(_) {});
		emitter.on(PING, self);
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
		Assert.isFalse(emitter.hasEventListener(PING, self));
	}

	function testAListenerMayRemoveAndAddItselfAgain() {
		var emitter = new Emitter();
		var log = [];
		var self:Event->Void = null;
		self = function(_:Event) {
			log.push("self");
			emitter.off(PING, self);
			emitter.on(PING, self);
		};
		emitter.on(PING, self);
		emitter.on(PING, function(_) log.push("other"));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("self,other", log.join(","));
		// Added again, it went to the end.
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("self,other,other,self", log.join(","));
		Assert.isTrue(emitter.hasEventListener(PING, self));
	}

	function testHasEventListenerIsExactDuringADispatch() {
		var emitter = new Emitter();
		var answers = [];
		var b = function(_:Event) {};
		emitter.on(PING, function(_) {
			answers.push(emitter.hasEventListener(PING, b));
			emitter.off(PING, b);
			answers.push(emitter.hasEventListener(PING, b));
			answers.push(emitter.hasEventListener(PING));
			emitter.removeEventListeners(PING);
			answers.push(emitter.hasEventListener(PING));
			emitter.addEventListener("other", b);
			answers.push(emitter.hasEventListener("other"));
		});
		emitter.on(PING, b);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("true,false,true,false,true", answers.join(","));
	}

	function testRemovingEverythingDuringADispatchLetsItFinish() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) {
			log.push("a");
			emitter.removeAllListeners();
		});
		emitter.on(PING, function(_) log.push("b"));
		emitter.dispatchEvent(new Event(PING));
		Assert.isFalse(emitter.dispatchEvent(new Event(PING)));
		Assert.equals("a,b", log.join(","));
	}

	function testANestedDispatchSeesTheListenersAsTheyAreThen() {
		var emitter = new Emitter();
		var log = [];
		var depth = 0;
		var c = function(_:Event) log.push("c" + depth);
		emitter.on(PING, function(e:Event) {
			log.push("a" + depth);
			if (depth == 0) {
				depth++;
				emitter.off(PING, c);
				emitter.dispatchEvent(new Event(PING));
				depth--;
			}
		});
		emitter.on(PING, function(_) log.push("b" + depth));
		emitter.on(PING, c);
		emitter.dispatchEvent(new Event(PING));
		// The nested dispatch no longer has c; the outer one still does.
		Assert.equals("a0,a1,b1,b0,c0", log.join(","));
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testAOnceListenerRunsOnceEvenWhenANestedDispatchReachesItFirst() {
		var emitter = new Emitter();
		var onceCalls = 0;
		var nested = false;
		emitter.on(PING, function(_) {
			if (!nested) {
				nested = true;
				emitter.dispatchEvent(new Event(PING));
			}
		});
		emitter.once(PING, function(_) onceCalls++);
		emitter.on(PING, function(_) {});
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, onceCalls);
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testAOnceListenerCancelledDuringTheDispatchStillRunsForIt() {
		// The same rule as any other listener removed during a dispatch.
		var emitter = new Emitter();
		var calls = 0;
		var pending = function(_:Event) calls++;
		emitter.on(PING, function(_) emitter.off(PING, pending));
		emitter.once(PING, pending);
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
	}

	function testListsChangedDuringADispatchKeepTheirOrder() {
		var emitter = new Emitter();
		var log = [];
		var once = true;
		emitter.on(PING, function(_) {
			log.push("a");
			if (once) {
				once = false;
				emitter.on(PING, function(_) log.push("high"), 10);
				emitter.on(PING, function(_) log.push("low"), -10);
			}
		});
		emitter.on(PING, function(_) log.push("b"));
		emitter.dispatchEvent(new Event(PING));
		log = [];
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("high,a,b,low", log.join(","));
	}
}
