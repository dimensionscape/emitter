package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal1;
import emitter.Subscription;
import support.Support;
import utest.Assert;
import utest.Test;

/** What `on` and `once` answer with: a subscription to cancel. **/
class SubscriptionTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var VALUE:Signal1<Int> = "value";

	function testCancellingRemovesTheListener() {
		var emitter = new Emitter();
		var log = [];
		var event = emitter.on(PING, function(_) log.push("event"));
		var signal = emitter.on(VALUE, function(v) log.push("signal" + v));
		Assert.isTrue(event.active);
		Assert.isTrue(signal.active);
		event.cancel();
		signal.cancel();
		Assert.isFalse(event.active);
		Assert.isFalse(signal.active);
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.isFalse(emitter.emit(VALUE, 1));
		Assert.equals("", log.join(","));
	}

	function testALambdaIsRemovedByItsSubscriptionAlone() {
		// Two lambdas alike in every way: no function equality is needed to
		// tell which one goes.
		var emitter = new Emitter();
		var log = [];
		var subscriptions = [for (i in 0...2) emitter.on(VALUE, function(v) log.push("listener" + i))];
		subscriptions[0].cancel();
		emitter.emit(VALUE, 0);
		Assert.equals("listener1", log.join(","));
	}

	function testCancellingTwiceIsNothing() {
		var emitter = new Emitter();
		var other = emitter.on(PING, function(_) {});
		var subscription = emitter.on(PING, function(_) {});
		subscription.cancel();
		subscription.cancel();
		Assert.isTrue(other.active);
		Assert.isTrue(emitter.has(PING));
	}

	function testCancellingDuringADispatchLetsItRunForThatDispatch() {
		var emitter = new Emitter();
		var log = [];
		var laterListener = function(_:Event) log.push("later");
		var later:Null<Subscription> = null;
		var answers = [];
		emitter.on(PING, function(_) {
			log.push("first");
			later.cancel();
			answers.push(later.active);
			answers.push(emitter.has(PING, laterListener));
		});
		later = emitter.on(PING, laterListener);
		emitter.dispatch(new Event(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals("first,later,first", log.join(","));
		Assert.equals("false,false,false,false", answers.join(","));
	}

	function testCancellingDuringAnEmitLetsItRunForThatEmit() {
		var emitter = new Emitter();
		var log = [];
		var later:Null<Subscription> = null;
		emitter.on(VALUE, function(_) {
			log.push("first");
			later.cancel();
		});
		later = emitter.on(VALUE, function(_) log.push("later"));
		emitter.emit(VALUE, 1);
		emitter.emit(VALUE, 2);
		Assert.equals("first,later,first", log.join(","));
	}

	function testAListenerMayCancelItself() {
		var emitter = new Emitter();
		var calls = 0;
		var self:Null<Subscription> = null;
		self = emitter.on(VALUE, function(_) {
			calls++;
			self.cancel();
		});
		emitter.emit(VALUE, 1);
		emitter.emit(VALUE, 2);
		Assert.equals(1, calls);
		Assert.isFalse(self.active);
	}

	function testCancellingAOnceBeforeItRunsKeepsItFromRunning() {
		var emitter = new Emitter();
		var calls = 0;
		var once = emitter.once(PING, function(_) calls++);
		Assert.isTrue(once.active);
		once.cancel();
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.equals(0, calls);
	}

	function testCancellingAOnceThatRanIsNothing() {
		var emitter = new Recording();
		var calls = 0;
		var once = emitter.once(PING, function(_) calls++);
		var stays = emitter.on(PING, function(_) {});
		emitter.dispatch(new Event(PING));
		Assert.isFalse(once.active);
		once.cancel();
		Assert.isTrue(stays.active);
		Assert.equals(1, calls);
		Assert.equals("ping+", emitter.log());
	}

	function testAOnceIsNoLongerActiveWhileItRuns() {
		var emitter = new Emitter();
		var inside:Null<Bool> = null;
		var once:Null<Subscription> = null;
		once = emitter.once(VALUE, function(_) inside = once.active);
		emitter.emit(VALUE, 1);
		Assert.isFalse(inside);
	}

	function testCancellingAfterClearIsNothing() {
		var emitter = new Emitter();
		var listener = function(_:Event) {};
		var before = emitter.on(PING, listener);
		var signal = emitter.on(VALUE, function(_) {});
		emitter.clear();
		Assert.isFalse(before.active);
		Assert.isFalse(signal.active);
		// The listener added again after clear is another one: the old
		// subscription does not reach it.
		var after = emitter.on(PING, listener);
		before.cancel();
		signal.cancel();
		Assert.isTrue(after.active);
		Assert.isTrue(emitter.has(PING, listener));
	}

	function testCancellingAfterClearOfItsTypeOrOffIsNothing() {
		var emitter = new Emitter();
		var listener = function(_:Event) {};
		var cleared = emitter.on(PING, listener);
		emitter.clear(PING);
		Assert.isFalse(cleared.active);
		var removed = emitter.on(PING, listener);
		emitter.off(PING, listener);
		Assert.isFalse(removed.active);
		var current = emitter.on(PING, listener);
		cleared.cancel();
		removed.cancel();
		Assert.isTrue(current.active);
		Assert.isTrue(emitter.has(PING));
	}

	function testWithDuplicatesKeptEachSubscriptionIsItsOwnListener() {
		var emitter = new Emitter();
		emitter.allowDuplicates = true;
		var calls = 0;
		var listener = function(_:Event) calls++;
		var first = emitter.on(PING, listener);
		var second = emitter.on(PING, listener);
		second.cancel();
		Assert.isTrue(first.active);
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testASubscriptionOutlivesItsEmitterBeingEmptiedAndFilled() {
		// A lane dropped by clear and made again: an old subscription
		// cancels nothing in the new one.
		var emitter = new Emitter();
		var listener = function(v:Int) {};
		var old = emitter.on(VALUE, listener);
		emitter.clear();
		emitter.on(VALUE, listener);
		old.cancel();
		Assert.isTrue(emitter.has(VALUE, listener));
		Assert.isTrue(emitter.emit(VALUE, 1));
	}
}
