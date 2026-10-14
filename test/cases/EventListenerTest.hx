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
		emitter.on(PING, function(e:Event) got = e);
		var event = new Event(PING);
		Assert.isTrue(emitter.dispatch(event));
		Assert.equals(event, got);
	}

	function testATypedListenerGetsItsOwnEventClass() {
		var emitter = new Emitter();
		var total = 0;
		emitter.on(ValueEvent.VALUE, function(e:ValueEvent) total += e.value);
		emitter.dispatch(new ValueEvent(ValueEvent.VALUE, 7));
		Assert.equals(7, total);
	}

	function testListenersOfOnePriorityRunFirstInFirstOut() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("a"));
		emitter.on(PING, function(_) log.push("b"));
		emitter.on(PING, function(_) log.push("c"));
		emitter.dispatch(new Event(PING));
		Assert.equals("a,b,c", log.join(","));
	}

	function testAHigherPriorityRunsEarlierAndTiesKeepTheirOrder() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("zero"));
		emitter.on(PING, function(_) log.push("five"), 5);
		emitter.on(PING, function(_) log.push("minus"), -1);
		emitter.on(PING, function(_) log.push("five2"), 5);
		emitter.on(PING, function(_) log.push("zero2"));
		emitter.dispatch(new Event(PING));
		Assert.equals("five,five2,zero,zero2,minus", log.join(","));
	}

	function testAHigherPriorityGoesBeforeThoseAlreadyThere() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("a"));
		emitter.on(PING, function(_) log.push("b"));
		emitter.on(PING, function(_) log.push("first"), 1);
		emitter.on(PING, function(_) log.push("last"), -1);
		emitter.dispatch(new Event(PING));
		Assert.equals("first,a,b,last", log.join(","));
	}

	function testAListenerAddedAgainIsIgnoredByDefault() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.on(PING, listener);
		emitter.on(PING, listener);
		emitter.on(PING, listener);
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);

		emitter.off(PING, listener);
		Assert.isFalse(emitter.has(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnIgnoredDuplicateKeepsItsPlaceAndPriority() {
		var emitter = new Emitter();
		var log = [];
		var first = function(_:Event) log.push("first");
		emitter.on(PING, first);
		emitter.on(PING, function(_) log.push("second"));
		emitter.on(PING, first, 10);
		emitter.once(PING, first, 20);
		emitter.dispatch(new Event(PING));
		Assert.equals("first,second", log.join(","));
	}

	function testOnceOfAListenerAlreadyThereIsIgnored() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.on(PING, listener);
		emitter.once(PING, listener);
		emitter.dispatch(new Event(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals(2, calls);
		Assert.isTrue(emitter.has(PING, listener));
	}

	function testAllowDuplicatesAddsItAgainAndEachRemovalTakesOne() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.allowDuplicates);
		emitter.allowDuplicates = true;
		Assert.isTrue(emitter.allowDuplicates);
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.on(PING, listener);
		emitter.on(PING, listener);
		emitter.dispatch(new Event(PING));
		Assert.equals(2, calls);

		emitter.off(PING, listener);
		emitter.dispatch(new Event(PING));
		Assert.equals(3, calls);

		emitter.off(PING, listener);
		emitter.dispatch(new Event(PING));
		Assert.equals(3, calls);
		Assert.isFalse(emitter.has(PING));
	}

	function testTheDuplicatePolicyIsPerEmitter() {
		var keeping = new Emitter();
		keeping.allowDuplicates = true;
		var plain = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		keeping.on(PING, listener);
		keeping.on(PING, listener);
		plain.on(PING, listener);
		plain.on(PING, listener);
		keeping.dispatch(new Event(PING));
		Assert.equals(2, calls);
		plain.dispatch(new Event(PING));
		Assert.equals(3, calls);
	}

	function testRemovingWhatIsNotThereDoesNothing() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.off(PING, listener);
		emitter.on(PING, listener);
		emitter.off(PONG, listener);
		emitter.off(PING, function(_) {});
		emitter.off(PING, null);
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testANullListenerOrTypeIsRefused() {
		var emitter = new Emitter();
		Assert.raises(() -> emitter.on(PING, null), haxe.exceptions.ArgumentException);
		Assert.raises(() -> emitter.on((null : EventType<Event>), function(_) {}), haxe.exceptions.ArgumentException);
		Assert.isFalse(emitter.has(PING));
	}

	function testRemoveEventListenersOfOneTypeOrAll() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("ping"));
		emitter.on(PING, function(_) log.push("ping2"));
		emitter.on(PONG, function(_) log.push("pong"));
		emitter.clear(PING);
		Assert.isFalse(emitter.has(PING));
		Assert.isTrue(emitter.has(PONG));
		emitter.dispatch(new Event(PING));
		emitter.dispatch(new Event(PONG));
		Assert.equals("pong", log.join(","));

		emitter.on(PING, function(_) log.push("again"));
		emitter.clear();
		Assert.isFalse(emitter.has(PING));
		Assert.isFalse(emitter.has(PONG));
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.equals("pong", log.join(","));
	}

	function testRemoveAllListenersEmptiesBothLanes() {
		var emitter = new Emitter();
		var SIGNAL:Signal0 = "ping";
		emitter.on(PING, function(_) {});
		emitter.on(SIGNAL, function() {});
		emitter.clear();
		Assert.isFalse(emitter.has(PING));
		Assert.isFalse(emitter.has(SIGNAL));
		Assert.isFalse(emitter.emit(SIGNAL));
	}

	function testADuplicateAnswersWithTheSubscriptionAlreadyThere() {
		var emitter = new Emitter();
		var listener = function(_:Event) {};
		var before = emitter.on(PING, function(_:Event) {});
		var first = emitter.on(PING, listener);
		var again = emitter.on(PING, listener, 5);
		Assert.equals(first, again);
		again.cancel();
		Assert.isFalse(first.active);
		Assert.isTrue(before.active);
		Assert.isFalse(emitter.has(PING, listener));
		before.cancel();
		Assert.isFalse(emitter.has(PING));
	}

	function testOnceRunsForTheNextEventOnly() {
		var emitter = new Emitter();
		var calls = 0;
		emitter.once(PING, function(_) calls++);
		Assert.isTrue(emitter.dispatch(new Event(PING)));
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.equals(1, calls);
		Assert.isFalse(emitter.has(PING));
	}

	function testOffCancelsAOnceBeforeItRuns() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.once(PING, listener);
		Assert.isTrue(emitter.has(PING, listener));
		emitter.off(PING, listener);
		Assert.isFalse(emitter.has(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals(0, calls);
	}

	function testAOnceListenerIsGoneWhileItRuns() {
		var emitter = new Emitter();
		var inside:Null<Bool> = null;
		var listener:Event->Void = null;
		listener = function(_:Event) inside = emitter.has(PING, listener);
		emitter.once(PING, listener);
		emitter.dispatch(new Event(PING));
		Assert.isFalse(inside);
	}

	function testAOnceListenerMayAddItselfAgain() {
		var emitter = new Emitter();
		var calls = 0;
		var listener:Event->Void = null;
		listener = function(_:Event) {
			calls++;
			if (calls < 3) {
				emitter.once(PING, listener);
			}
		};
		emitter.once(PING, listener);
		for (_ in 0...5) {
			emitter.dispatch(new Event(PING));
		}
		Assert.equals(3, calls);
	}

	function testOnceKeepsItsPriority() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("plain"));
		emitter.once(PING, function(_) log.push("once"), 1);
		emitter.dispatch(new Event(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals("once,plain,plain", log.join(","));
	}

	function testHasEventListenerWithAListenerSaysWhetherThatOneListens() {
		var emitter = new Emitter();
		var a = function(_:Event) {};
		var b = function(_:Event) {};
		Assert.isFalse(emitter.has(PING, a));
		emitter.on(PING, a);
		Assert.isTrue(emitter.has(PING));
		Assert.isTrue(emitter.has(PING, a));
		Assert.isFalse(emitter.has(PING, b));
		Assert.isFalse(emitter.has(PONG, a));
		emitter.off(PING, a);
		Assert.isFalse(emitter.has(PING, a));
	}

	function testManyTypesAreAllFoundAndForgotten() {
		// Past the chain natively (8 types) and on JavaScript (4): into a map,
		// then out of it and back to the chain once all are gone.
		var emitter = new Emitter();
		var heard = [];
		for (i in 0...20) {
			var name = "type" + i;
			emitter.on(name, function(e:Event) heard.push(e.type));
		}
		for (i in 0...20) {
			Assert.isTrue(emitter.has("type" + i));
			Assert.isTrue(emitter.dispatch(new Event("type" + i)));
		}
		Assert.equals(20, heard.length);
		Assert.equals("type13", heard[13]);
		Assert.isFalse(emitter.has("type20"));
		Assert.isFalse(emitter.dispatch(new Event("type20")));

		for (i in 0...20) {
			emitter.clear("type" + i);
			Assert.isFalse(emitter.has("type" + i));
		}
		emitter.on("again", function(e:Event) heard.push(e.type));
		emitter.dispatch(new Event("again"));
		Assert.equals("again", heard[20]);
	}

	function testRemovingAnyOfAFewTypesKeepsTheOthers() {
		// Within the chain natively and on JavaScript: the first type, one in
		// the middle and the last each go, and the rest are still found.
		var emitter = new Emitter();
		var heard = [];
		var listen = function(name:String) emitter.on(name, function(e:Event) heard.push(e.type));
		for (name in ["a", "b", "c", "d"]) {
			listen(name);
		}
		emitter.clear("a");
		emitter.clear("c");
		listen("e");
		emitter.clear("e");
		listen("f");
		for (name in ["a", "b", "c", "d", "e", "f"]) {
			emitter.dispatch(new Event(name));
		}
		Assert.equals("b,d,f", heard.join(","));
		emitter.clear("b");
		emitter.clear("d");
		emitter.clear("f");
		Assert.isFalse(emitter.has("b"));
		Assert.isFalse(emitter.has("f"));
		listen("g");
		Assert.isTrue(emitter.dispatch(new Event("g")));
		Assert.equals("b,d,f,g", heard.join(","));
	}

	function testANullTypeHasNoListenersWhateverTheEmitterHolds() {
		var emitter = new Emitter();
		var none:EventType<Event> = null;
		var noSignal:Signal0 = null;
		Assert.isFalse(emitter.has(none));
		emitter.allowDuplicates = true;
		Assert.isFalse(emitter.has(none));
		emitter.on(PING, function(_) {});
		Assert.isFalse(emitter.has(none));
		emitter.clear(PING);
		Assert.isFalse(emitter.has(none));
		Assert.isFalse(emitter.dispatch(new Event(null)));
		Assert.isFalse(emitter.has(noSignal));
		emitter.on(PING, function(_) {});
		emitter.clear(none);
		Assert.isTrue(emitter.has(PING));
	}

	function testATypeMadeAtRunTimeFindsTheListenersOfTheSameText() {
		// Natively types are compared by which string they are first: a
		// string built at run time is another one with the same text.
		var emitter = new Emitter();
		var calls = 0;
		emitter.on("change", function(_) calls++);
		emitter.on("other", function(_) {});
		var built = ["ch", "ange"].join("");
		Assert.isTrue(emitter.has(built));
		Assert.isTrue(emitter.dispatch(new Event(built)));
		Assert.equals(1, calls);
		emitter.clear(built);
		Assert.isFalse(emitter.has("change"));
	}

	function testDispatchSaysWhetherAnythingListened() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		emitter.on(PONG, function(_) {});
		Assert.isFalse(emitter.dispatch(new Event(PING)));
		Assert.isTrue(emitter.dispatch(new Event(PONG)));
		Assert.isFalse(emitter.dispatch(null));
	}

	function testListenersOfOneEmitterAreNotAnothers() {
		var a = new Emitter();
		var b = new Emitter();
		var calls = 0;
		a.on(PING, function(_) calls++);
		Assert.isFalse(b.has(PING));
		Assert.isFalse(b.dispatch(new Event(PING)));
		Assert.equals(0, calls);
	}

	function testAHolderOfAnEmitterIsDispatchedOnThroughIEmitter() {
		var holder = new Holder();
		var target:Null<IEmitter> = null;
		var listener = function(e:Event) target = e.target;
		holder.on(PING, listener);
		Assert.isTrue(holder.has(PING));
		var asInterface:IEmitter = holder;
		Assert.isTrue(asInterface.dispatch(new Event(PING)));
		Assert.equals(asInterface, target);
		holder.off(PING, listener);
		Assert.isFalse(holder.has(PING));
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
