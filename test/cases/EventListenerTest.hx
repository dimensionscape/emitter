package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import emitter.Signal0;
import support.Support;
import utest.Assert;
import utest.Test;

/** Adding, ordering, finding and removing event listeners. **/
class EventListenerTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";

	function testAListenerIsHandedTheEventItself() {
		var emitter = new Emitter();
		var got:Null<Event> = null;
		emitter.events.on(PING, function(e:Event) got = e);
		var event = new Event(PING);
		Assert.isTrue(emitter.events.dispatch(event));
		Assert.equals(event, got);
	}

	function testATypedListenerGetsItsOwnEventClass() {
		var emitter = new Emitter();
		var total = 0;
		emitter.events.on(ValueEvent.VALUE, function(e:ValueEvent) total += e.value);
		emitter.events.dispatch(new ValueEvent(ValueEvent.VALUE, 7));
		Assert.equals(7, total);
	}

	function testListenersOfOnePriorityRunFirstInFirstOut() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.on(PING, function(_) log.push("c"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b,c", log.join(","));
	}

	function testAHigherPriorityRunsEarlierAndTiesKeepTheirOrder() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("zero"));
		emitter.events.on(PING, function(_) log.push("five"), 5);
		emitter.events.on(PING, function(_) log.push("minus"), -1);
		emitter.events.on(PING, function(_) log.push("five2"), 5);
		emitter.events.on(PING, function(_) log.push("zero2"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("five,five2,zero,zero2,minus", log.join(","));
	}

	function testAHigherPriorityGoesBeforeThoseAlreadyThere() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.on(PING, function(_) log.push("first"), 1);
		emitter.events.on(PING, function(_) log.push("last"), -1);
		emitter.events.dispatch(new Event(PING));
		Assert.equals("first,a,b,last", log.join(","));
	}

	function testAListenerAddedAgainIsIgnoredByDefault() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.events.on(PING, listener);
		emitter.events.on(PING, listener);
		emitter.events.on(PING, listener);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);

		emitter.events.off(PING, listener);
		Assert.isFalse(emitter.events.has(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnIgnoredDuplicateKeepsItsPlaceAndPriority() {
		var emitter = new Emitter();
		var log = [];
		var first = function(_:Event) log.push("first");
		emitter.events.on(PING, first);
		emitter.events.on(PING, function(_) log.push("second"));
		emitter.events.on(PING, first, 10);
		emitter.events.once(PING, first, 20);
		emitter.events.dispatch(new Event(PING));
		Assert.equals("first,second", log.join(","));
	}

	function testOnceOfAListenerAlreadyThereIsIgnored() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.events.on(PING, listener);
		emitter.events.once(PING, listener);
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(2, calls);
		Assert.isTrue(emitter.events.has(PING, listener));
	}

	function testAllowDuplicatesAddsItAgainAndEachRemovalTakesOne() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.allowDuplicates);
		emitter.allowDuplicates = true;
		Assert.isTrue(emitter.allowDuplicates);
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.events.on(PING, listener);
		emitter.events.on(PING, listener);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(2, calls);

		emitter.events.off(PING, listener);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(3, calls);

		emitter.events.off(PING, listener);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(3, calls);
		Assert.isFalse(emitter.events.has(PING));
	}

	function testTheDuplicatePolicyIsPerEmitter() {
		var keeping = new Emitter();
		keeping.allowDuplicates = true;
		var plain = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		keeping.events.on(PING, listener);
		keeping.events.on(PING, listener);
		plain.events.on(PING, listener);
		plain.events.on(PING, listener);
		keeping.events.dispatch(new Event(PING));
		Assert.equals(2, calls);
		plain.events.dispatch(new Event(PING));
		Assert.equals(3, calls);
	}

	function testRemovingWhatIsNotThereDoesNothing() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.events.off(PING, listener);
		emitter.events.on(PING, listener);
		emitter.events.off(PONG, listener);
		emitter.events.off(PING, function(_) {});
		emitter.events.off(PING, null);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testANullListenerOrTypeIsRefused() {
		var emitter = new Emitter();
		Assert.raises(() -> emitter.events.on(PING, null), haxe.exceptions.ArgumentException);
		Assert.raises(() -> emitter.events.on((null : EventType<Event>), function(_) {}), haxe.exceptions.ArgumentException);
		Assert.isFalse(emitter.events.has(PING));
	}

	function testRemoveEventListenersOfOneTypeOrAll() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("ping"));
		emitter.events.on(PING, function(_) log.push("ping2"));
		emitter.events.on(PONG, function(_) log.push("pong"));
		emitter.events.clear(PING);
		Assert.isFalse(emitter.events.has(PING));
		Assert.isTrue(emitter.events.has(PONG));
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PONG));
		Assert.equals("pong", log.join(","));

		emitter.events.on(PING, function(_) log.push("again"));
		emitter.events.clear();
		Assert.isFalse(emitter.events.has(PING));
		Assert.isFalse(emitter.events.has(PONG));
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		Assert.equals("pong", log.join(","));
	}

	function testRemoveAllListenersEmptiesBothLanes() {
		var emitter = new Emitter();
		var SIGNAL:Signal0 = "ping";
		emitter.events.on(PING, function(_) {});
		emitter.events.on(SIGNAL, function() {});
		emitter.events.clear();
		Assert.isFalse(emitter.events.has(PING));
		Assert.isFalse(emitter.events.has(SIGNAL));
		Assert.isFalse(emitter.events.emit(SIGNAL));
	}

	function testADuplicateAnswersWithTheSubscriptionAlreadyThere() {
		var emitter = new Emitter();
		var listener = function(_:Event) {};
		var before = emitter.events.on(PING, function(_:Event) {});
		var first = emitter.events.on(PING, listener);
		var again = emitter.events.on(PING, listener, 5);
		Assert.equals(first, again);
		again.cancel();
		Assert.isFalse(first.active);
		Assert.isTrue(before.active);
		Assert.isFalse(emitter.events.has(PING, listener));
		before.cancel();
		Assert.isFalse(emitter.events.has(PING));
	}

	function testOnceRunsForTheNextEventOnly() {
		var emitter = new Emitter();
		var calls = 0;
		emitter.events.once(PING, function(_) calls++);
		Assert.isTrue(emitter.events.dispatch(new Event(PING)));
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		Assert.equals(1, calls);
		Assert.isFalse(emitter.events.has(PING));
	}

	function testOffCancelsAOnceBeforeItRuns() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.events.once(PING, listener);
		Assert.isTrue(emitter.events.has(PING, listener));
		emitter.events.off(PING, listener);
		Assert.isFalse(emitter.events.has(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(0, calls);
	}

	function testAOnceListenerIsGoneWhileItRuns() {
		var emitter = new Emitter();
		var inside:Null<Bool> = null;
		var listener:Event->Void = null;
		listener = function(_:Event) inside = emitter.events.has(PING, listener);
		emitter.events.once(PING, listener);
		emitter.events.dispatch(new Event(PING));
		Assert.isFalse(inside);
	}

	function testAOnceListenerMayAddItselfAgain() {
		var emitter = new Emitter();
		var calls = 0;
		var listener:Event->Void = null;
		listener = function(_:Event) {
			calls++;
			if (calls < 3) {
				emitter.events.once(PING, listener);
			}
		};
		emitter.events.once(PING, listener);
		for (_ in 0...5) {
			emitter.events.dispatch(new Event(PING));
		}
		Assert.equals(3, calls);
	}

	function testOnceKeepsItsPriority() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("plain"));
		emitter.events.once(PING, function(_) log.push("once"), 1);
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("once,plain,plain", log.join(","));
	}

	function testHasEventListenerWithAListenerSaysWhetherThatOneListens() {
		var emitter = new Emitter();
		var a = function(_:Event) {};
		var b = function(_:Event) {};
		Assert.isFalse(emitter.events.has(PING, a));
		emitter.events.on(PING, a);
		Assert.isTrue(emitter.events.has(PING));
		Assert.isTrue(emitter.events.has(PING, a));
		Assert.isFalse(emitter.events.has(PING, b));
		Assert.isFalse(emitter.events.has(PONG, a));
		emitter.events.off(PING, a);
		Assert.isFalse(emitter.events.has(PING, a));
	}

	function testManyTypesAreAllFoundAndForgotten() {
		// Past the chain natively (8 types) and on JavaScript (4): into a map,
		// then out of it and back to the chain once all are gone.
		var emitter = new Emitter();
		var heard = [];
		for (i in 0...20) {
			var name = "type" + i;
			emitter.events.on(name, function(e:Event) heard.push(e.type));
		}
		for (i in 0...20) {
			Assert.isTrue(emitter.events.has("type" + i));
			Assert.isTrue(emitter.events.dispatch(new Event("type" + i)));
		}
		Assert.equals(20, heard.length);
		Assert.equals("type13", heard[13]);
		Assert.isFalse(emitter.events.has("type20"));
		Assert.isFalse(emitter.events.dispatch(new Event("type20")));

		for (i in 0...20) {
			emitter.events.clear("type" + i);
			Assert.isFalse(emitter.events.has("type" + i));
		}
		emitter.events.on("again", function(e:Event) heard.push(e.type));
		emitter.events.dispatch(new Event("again"));
		Assert.equals("again", heard[20]);
	}

	function testRemovingAnyOfAFewTypesKeepsTheOthers() {
		// Within the chain natively and on JavaScript: the first type, one in
		// the middle and the last each go, and the rest are still found.
		var emitter = new Emitter();
		var heard = [];
		var listen = function(name:String) emitter.events.on(name, function(e:Event) heard.push(e.type));
		for (name in ["a", "b", "c", "d"]) {
			listen(name);
		}
		emitter.events.clear("a");
		emitter.events.clear("c");
		listen("e");
		emitter.events.clear("e");
		listen("f");
		for (name in ["a", "b", "c", "d", "e", "f"]) {
			emitter.events.dispatch(new Event(name));
		}
		Assert.equals("b,d,f", heard.join(","));
		emitter.events.clear("b");
		emitter.events.clear("d");
		emitter.events.clear("f");
		Assert.isFalse(emitter.events.has("b"));
		Assert.isFalse(emitter.events.has("f"));
		listen("g");
		Assert.isTrue(emitter.events.dispatch(new Event("g")));
		Assert.equals("b,d,f,g", heard.join(","));
	}

	function testANullTypeHasNoListenersWhateverTheEmitterHolds() {
		var emitter = new Emitter();
		var none:EventType<Event> = null;
		var noSignal:Signal0 = null;
		Assert.isFalse(emitter.events.has(none));
		emitter.allowDuplicates = true;
		Assert.isFalse(emitter.events.has(none));
		emitter.events.on(PING, function(_) {});
		Assert.isFalse(emitter.events.has(none));
		emitter.events.clear(PING);
		Assert.isFalse(emitter.events.has(none));
		Assert.isFalse(emitter.events.dispatch(new Event(null)));
		Assert.isFalse(emitter.events.has(noSignal));
		emitter.events.on(PING, function(_) {});
		emitter.events.clear(none);
		Assert.isTrue(emitter.events.has(PING));
	}

	function testATypeMadeAtRunTimeFindsTheListenersOfTheSameText() {
		// Natively types are compared by which string they are first: a
		// string built at run time is another one with the same text.
		var emitter = new Emitter();
		var calls = 0;
		emitter.events.on("change", function(_) calls++);
		emitter.events.on("other", function(_) {});
		var built = ["ch", "ange"].join("");
		Assert.isTrue(emitter.events.has(built));
		Assert.isTrue(emitter.events.dispatch(new Event(built)));
		Assert.equals(1, calls);
		emitter.events.clear(built);
		Assert.isFalse(emitter.events.has("change"));
	}

	function testDispatchSaysWhetherAnythingListened() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		emitter.events.on(PONG, function(_) {});
		Assert.isFalse(emitter.events.dispatch(new Event(PING)));
		Assert.isTrue(emitter.events.dispatch(new Event(PONG)));
		Assert.isFalse(emitter.events.dispatch(null));
	}

	function testListenersOfOneEmitterAreNotAnothers() {
		var a = new Emitter();
		var b = new Emitter();
		var calls = 0;
		a.events.on(PING, function(_) calls++);
		Assert.isFalse(b.events.has(PING));
		Assert.isFalse(b.events.dispatch(new Event(PING)));
		Assert.equals(0, calls);
	}

	function testAHolderOfAnEmitterIsDispatchedOnThroughIEmitter() {
		var holder = new Holder();
		var target:Null<IEmitter> = null;
		var listener = function(e:Event) target = e.target;
		holder.events.on(PING, listener);
		Assert.isTrue(holder.events.has(PING));
		var asInterface:IEmitter = holder;
		Assert.isTrue(asInterface.events.dispatch(new Event(PING)));
		Assert.equals(asInterface, target);
		holder.events.off(PING, listener);
		Assert.isFalse(holder.events.has(PING));
	}

	function testAFrameworksActionScriptNamesForwardToTheCore() {
		var dispatcher = new FlashDispatcher();
		var log = [];
		var listener = function(e:Event) log.push(e.type);
		dispatcher.addEventListener(PING, listener);
		dispatcher.addEventListener(PING, listener);
		Assert.isTrue(dispatcher.hasEventListener("ping"));
		Assert.isTrue(dispatcher.dispatchEvent(new Event(PING)));
		dispatcher.removeEventListener(PING, listener);
		Assert.isFalse(dispatcher.hasEventListener("ping"));
		dispatcher.addEventListener(PONG, listener);
		dispatcher.removeEventListeners();
		Assert.isFalse(dispatcher.dispatchEvent(new Event(PONG)));
		Assert.equals("ping", log.join(","));
	}
}
