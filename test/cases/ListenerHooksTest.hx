package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal1;
import emitter.Subscription;
import utest.Assert;
import utest.Test;

/**
	The hooks that tell a framework of each listener (`listenerAdded`,
	`listenerRemoved`), what `listenersOf` lists, and calling a listener
	through `Subscription.listener`: from every path that adds or removes, on
	every target.
**/
class ListenerHooksTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";
	static inline var VALUE:Signal1<Int> = "value";

	/** PING's name, for the emitters below. **/
	public static inline var PING_NAME:String = "ping";

	function testEachListenerAddedIsReportedWithItsSubscription() {
		var emitter = new Witness();
		var a = emitter.on(PING, function(_) {});
		var b = emitter.on(PING, function(_) {}, 5);
		var c = emitter.once(PONG, function(_) {});
		Assert.equals("ping+,added ping,added ping,pong+,added pong", emitter.log());
		Assert.isTrue(emitter.added[0] == a, "the first report is not the first subscription");
		Assert.isTrue(emitter.added[1] == b, "the second report is not the second subscription");
		Assert.isTrue(emitter.added[2] == c, "the once listener's report is not its subscription");
	}

	function testTheFirstIsReportedAfterItsTypeAndTheLastBeforeIt() {
		// As brackets: the type opens, then its listener; its listener goes,
		// then the type closes.
		var emitter = new Witness();
		var listener = function(_:Event) {};
		emitter.on(PING, listener);
		emitter.off(PING, listener);
		Assert.equals("ping+,added ping,removed ping,ping-", emitter.log());
	}

	function testAnIgnoredDuplicateIsNotReported() {
		var emitter = new Witness();
		var listener = function(_:Event) {};
		emitter.on(PING, listener);
		emitter.on(PING, listener);
		emitter.once(PING, listener, 3);
		Assert.equals("ping+,added ping", emitter.log());

		var keeping = new Witness();
		keeping.allowDuplicates = true;
		var first = keeping.on(PING, listener);
		var second = keeping.on(PING, listener);
		Assert.equals("ping+,added ping,added ping", keeping.log());
		Assert.isTrue(keeping.added[0] == first && keeping.added[1] == second, "each duplicate kept was not reported with its own subscription");
	}

	function testOffAndCancelReportTheListenerTakenOut() {
		var emitter = new Witness();
		var a = function(_:Event) {};
		var b = function(_:Event) {};
		var first = emitter.on(PING, a);
		var second = emitter.on(PING, b);
		emitter.clearLog();
		emitter.off(PING, b);
		emitter.off(PING, b);
		Assert.equals("removed ping", emitter.log());
		Assert.isTrue(emitter.removed[0] == second, "off reported another subscription");
		first.cancel();
		first.cancel();
		Assert.equals("removed ping,removed ping,ping-", emitter.log());
		Assert.isTrue(emitter.removed[1] == first, "cancel reported another subscription");
	}

	function testABoundMethodTakenOffIsReported() {
		// Read again for off: a new closure on eval and the jvm.
		var emitter = new Witness();
		var subscriber = new Subscriber();
		var subscription = emitter.on(PING, subscriber.handle);
		emitter.clearLog();
		emitter.off(PING, subscriber.handle);
		Assert.equals("removed ping,ping-", emitter.log());
		Assert.isTrue(emitter.removed[0] == subscription);
	}

	function testAOnceListenerCalledIsReportedOnce() {
		// Alone, among others, spent first by a nested dispatch, and in a
		// contained dispatch.
		var alone = new Witness();
		var single = alone.once(PING, function(_) {});
		alone.clearLog();
		alone.dispatch(new Event(PING));
		alone.dispatch(new Event(PING));
		Assert.equals("removed ping,ping-", alone.log());
		Assert.isTrue(alone.removed[0] == single);

		var among = new Witness();
		among.on(PING, function(_) {});
		var spent = among.once(PING, function(_) {});
		among.on(PING, function(_) {});
		among.clearLog();
		among.dispatch(new Event(PING));
		among.dispatch(new Event(PING));
		Assert.equals("removed ping", among.log());
		Assert.isTrue(among.removed[0] == spent);

		var nested = new Witness();
		var outer = true;
		nested.on(PING, function(_) {
			if (outer) {
				outer = false;
				nested.dispatch(new Event(PING));
			}
		});
		var inner = nested.once(PING, function(_) {});
		nested.clearLog();
		nested.dispatch(new Event(PING));
		Assert.equals("removed ping", nested.log());
		Assert.isTrue(nested.removed[0] == inner);

		var contained = new Witness();
		var spentContained = contained.once(PING, function(_) {});
		contained.on(PING, function(_) {});
		contained.clearLog();
		contained.dispatchContained(new Event(PING));
		Assert.equals("removed ping", contained.log());
		Assert.isTrue(contained.removed[0] == spentContained);
	}

	function testAOnceTakenOffDuringADispatchIsReportedOnlyAsItGoes() {
		// It still runs for the dispatch it was taken off in, which then
		// finds it gone: one report, not two.
		var emitter = new Witness();
		var late = function(_:Event) {};
		emitter.on(PING, function(_) emitter.off(PING, late));
		var subscription = emitter.once(PING, late);
		emitter.clearLog();
		emitter.dispatch(new Event(PING));
		Assert.equals("removed ping", emitter.log());
		Assert.isTrue(emitter.removed[0] == subscription);
		Assert.equals(1, emitter.removed.length);
	}

	function testClearReportsEachListenerAndThenItsType() {
		var emitter = new Witness();
		var a = emitter.on(PING, function(_) {});
		var b = emitter.on(PING, function(_) {}, 2);
		emitter.on(PONG, function(_) {});
		emitter.clearLog();
		emitter.clear(PING);
		emitter.clear(PING);
		Assert.equals("removed ping,removed ping,ping-", emitter.log());
		// In the order they ran.
		Assert.isTrue(emitter.removed[0] == b && emitter.removed[1] == a, "clear reported other subscriptions, or out of order");

		emitter.on("third", function(_:Event) {});
		emitter.on("third", function(_:Event) {});
		emitter.clearLog();
		emitter.clear();
		// Each type's listeners, then the type, in no particular order of types.
		var groups = emitter.log().split(",");
		Assert.equals(5, groups.length);
		var text = emitter.log();
		Assert.isTrue(text.indexOf("removed pong,pong-") >= 0, text);
		Assert.isTrue(text.indexOf("removed third,removed third,third-") >= 0, text);
		emitter.clearLog();
		emitter.clear();
		Assert.equals("", emitter.log());
	}

	function testClearPastTheChainReportsEveryListener() {
		// Past the names kept in a chain, into a map: the same reports.
		var emitter = new Witness();
		for (i in 0...12) {
			emitter.on("t" + i, function(_:Event) {});
			emitter.on("t" + i, function(_:Event) {});
		}
		emitter.clearLog();
		emitter.clear();
		Assert.equals(24, emitter.removed.length);
		Assert.equals(12, [for (entry in emitter.entries) if (entry.charAt(entry.length - 1) == "-") entry].length);
	}

	function testSignalsAreNotReported() {
		var emitter = new Witness();
		var subscription = emitter.on(VALUE, function(_) {});
		emitter.once(VALUE, function(_) {});
		emitter.emit(VALUE, 1);
		subscription.cancel();
		emitter.on(VALUE, function(_) {});
		emitter.clear(VALUE);
		emitter.on(VALUE, function(_) {});
		emitter.clear();
		Assert.equals("", emitter.log());
	}

	function testTheHooksSeeTheChangeAlreadyMade() {
		var emitter = new Witness();
		var listener = function(_:Event) {};
		emitter.on(PING, listener);
		emitter.on(PING, function(_) {});
		emitter.off(PING, listener);
		Assert.equals("true,true,true", emitter.listenedInside.join(","));
		Assert.equals("true,true,false", emitter.listenerInside.join(","));
		emitter.clear(PING);
		Assert.equals("true,true,true,false", emitter.listenedInside.join(","));
	}

	function testListenersOfListsInTheOrderTheyRun() {
		var emitter = new Lister();
		Assert.equals(0, emitter.listOf(PING).length);
		Assert.equals(0, emitter.listOf(null).length);
		var a = emitter.on(PING, function(_) {});
		var b = emitter.on(PING, function(_) {}, 5);
		var c = emitter.on(PING, function(_) {});
		var d = emitter.on(PING, function(_) {}, -1);
		emitter.on(PONG, function(_) {});
		var listed = emitter.listOf(PING);
		Assert.equals(4, listed.length);
		Assert.isTrue(listed[0] == b && listed[1] == a && listed[2] == c && listed[3] == d, "not in the order a dispatch runs them");

		// A copy: neither changes the other.
		c.cancel();
		Assert.equals(4, listed.length);
		listed.pop();
		Assert.equals(3, emitter.listOf(PING).length);
		Assert.isTrue(emitter.has(PING));
	}

	function testListenersOfDuringADispatchSaysWhatIsThereNow() {
		// A listener taken off mid-dispatch still runs for it, but is not
		// listed; one added is listed, though it waits for the next dispatch.
		var emitter = new Lister();
		var counts:Array<Int> = [];
		var second = function(_:Event) counts.push(emitter.listOf(PING).length);
		var added = function(_:Event) {};
		emitter.on(PING, function(_) {
			emitter.off(PING, second);
			emitter.on(PING, added);
			counts.push(emitter.listOf(PING).length);
		});
		emitter.on(PING, second);
		emitter.dispatch(new Event(PING));
		Assert.equals("2,2", counts.join(","));
	}

	function testListenersOfLeavesOutAOnceAlreadyCalled() {
		var emitter = new Lister();
		var kept = emitter.on(PING, function(_) {});
		emitter.once(PING, function(_) {});
		emitter.dispatch(new Event(PING));
		var listed = emitter.listOf(PING);
		Assert.equals(1, listed.length);
		Assert.isTrue(listed[0] == kept);
	}

	function testASubscriptionCallsItsListener() {
		var emitter = new Emitter();
		var heard:Array<String> = [];
		var listener = function(event:Event):Void {
			heard.push(event.type);
		};
		var subscription = emitter.on(PING, listener);
		var call:Event->Void = cast subscription.listener;
		call(new Event(PING));
		Assert.equals("ping", heard.join(","));
		#if !hl
		// HashLink keeps a typed function added through `on` wrapped.
		Assert.isTrue(subscription.listener == cast listener, "the function kept is not the one added");
		#end

		var values:Array<Int> = [];
		var signal = emitter.on(VALUE, function(v:Int):Void {
			values.push(v);
		});
		var emit:Int->Void = cast signal.listener;
		emit(7);
		Assert.equals("7", values.join(","));

		// Still there once removed: it is what the listener was.
		subscription.cancel();
		call = cast subscription.listener;
		call(new Event(PONG));
		Assert.equals("ping,pong", heard.join(","));
	}

	function testAFrameworkKeepsACopyOfItsListenersWhole() {
		// What a framework that calls listeners from another thread does:
		// keeps a copy of a type's listeners, its own left out, read again
		// whenever one comes or goes. Its own is told apart by its
		// subscription, which works where comparing functions does not
		// (HashLink keeps them wrapped).
		var publisher = new Publisher();
		var heard:Array<String> = [];
		var a = function(_:Event) heard.push("a");
		var subscriber = new Subscriber();
		publisher.on(PING, a);
		publisher.on(PING, subscriber.handle, 3);
		publisher.once(PING, function(_) heard.push("c"));
		var d = publisher.on(PING, function(_) heard.push("d"), -2);
		publisher.callCopy(new Event(PING));
		Assert.equals("a,c,d", heard.join(","));
		Assert.equals(1, subscriber.calls);

		heard = [];
		publisher.off(PING, subscriber.handle);
		d.cancel();
		publisher.callCopy(new Event(PING));
		Assert.equals("a,c", heard.join(","));
		Assert.equals(1, subscriber.calls);

		// The once listener called by a dispatch here leaves the copy too.
		heard = [];
		publisher.dispatch(new Event(PING));
		Assert.equals("a,c", heard.join(","));
		heard = [];
		publisher.callCopy(new Event(PING));
		Assert.equals("a", heard.join(","));

		publisher.clear(PING);
		Assert.equals(0, publisher.copy.length);
		publisher.on(PING, a);
		Assert.equals(1, publisher.copy.length);
		publisher.clear();
		Assert.equals(0, publisher.copy.length);
	}

	function testAFrameworkTellsAListenerAddedTooLateAlone() {
		// An emitter whose event happened already tells a listener added
		// afterwards, alone, later: the others heard it when it happened.
		var latch = new Latch();
		var log:Array<String> = [];
		latch.on(PING, function(_) log.push("early"));
		latch.happen();
		Assert.equals("early", log.join(","));

		latch.on(PING, function(_) log.push("late"));
		var gone = function(_:Event) log.push("gone");
		latch.on(PING, gone);
		latch.off(PING, gone);
		latch.flush();
		Assert.equals("early,late", log.join(","));
		latch.flush();
		Assert.equals("early,late", log.join(","));
	}
}

/** Records every hook, in the order they are called, in one log. **/
private class Witness extends Emitter {
	public var entries:Array<String> = [];
	public var added:Array<Subscription> = [];
	public var removed:Array<Subscription> = [];

	/** What `has(type)` said inside each per-listener hook. **/
	public var listenedInside:Array<Bool> = [];

	/** Whether the listener reported was listening, inside each per-listener hook. **/
	public var listenerInside:Array<Bool> = [];

	public function new() {
		super();
	}

	override private function listenersChanged(type:String, present:Bool):Void {
		entries.push(type + (present ? "+" : "-"));
	}

	override private function listenerAdded(type:String, listener:Subscription):Void {
		entries.push("added " + type);
		added.push(listener);
		listenedInside.push(has(type));
		listenerInside.push(listener.active);
	}

	override private function listenerRemoved(type:String, listener:Subscription):Void {
		entries.push("removed " + type);
		removed.push(listener);
		listenedInside.push(has(type));
		listenerInside.push(listener.active);
	}

	public function clearLog():Void {
		entries = [];
		added = [];
		removed = [];
		listenedInside = [];
		listenerInside = [];
	}

	public function log():String {
		return entries.join(",");
	}
}

/** Opens `listenersOf` to the tests. **/
private class Lister extends Emitter {
	public function new() {
		super();
	}

	public function listOf(type:String):Array<Subscription> {
		return listenersOf(type);
	}
}

/**
	Keeps `copy`, the functions listening for PING but its own, in the order
	they run, as a framework handing them to another thread would.
**/
private class Publisher extends Emitter {
	public var copy:Array<Event->Void> = [];

	var own:Subscription;

	public function new() {
		super();
		own = on(ListenerHooksTest.PING_NAME, function(_) {});
	}

	override private function listenerAdded(type:String, listener:Subscription):Void {
		refresh(type);
	}

	override private function listenerRemoved(type:String, listener:Subscription):Void {
		refresh(type);
	}

	function refresh(type:String):Void {
		if (type != ListenerHooksTest.PING_NAME) {
			return;
		}
		var next:Array<Event->Void> = [];
		for (subscription in listenersOf(type)) {
			if (subscription != own) {
				next.push(cast subscription.listener);
			}
		}
		copy = next;
	}

	public function callCopy(event:Event):Void {
		for (listener in copy) {
			listener(event);
		}
	}
}

/**
	Once `happen` has dispatched PING, tells each listener added afterwards
	alone, at the next `flush`, unless it has gone by then.
**/
private class Latch extends Emitter {
	var happened:Bool = false;
	var waiting:Array<Subscription> = [];

	public function new() {
		super();
	}

	public function happen():Void {
		happened = true;
		dispatch(new Event(ListenerHooksTest.PING_NAME));
	}

	override private function listenerAdded(type:String, listener:Subscription):Void {
		if (happened && type == ListenerHooksTest.PING_NAME) {
			waiting.push(listener);
		}
	}

	public function flush():Void {
		var due = waiting;
		waiting = [];
		for (subscription in due) {
			if (subscription.active) {
				var call:Event->Void = cast subscription.listener;
				call(new Event(ListenerHooksTest.PING_NAME));
			}
		}
	}
}

private class Subscriber {
	public var calls:Int = 0;

	public function new() {}

	public function handle(_:Event):Void {
		calls++;
	}
}
