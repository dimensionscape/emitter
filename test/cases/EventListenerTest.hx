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
		emitter.addEventListener(PING, function(e:Event) got = e);
		var event = new Event(PING);
		Assert.isTrue(emitter.dispatchEvent(event));
		Assert.equals(event, got);
	}

	function testATypedListenerGetsItsOwnEventClass() {
		var emitter = new Emitter();
		var total = 0;
		emitter.addEventListener(ValueEvent.VALUE, function(e:ValueEvent) total += e.value);
		emitter.dispatchEvent(new ValueEvent(ValueEvent.VALUE, 7));
		Assert.equals(7, total);
	}

	function testListenersOfOnePriorityRunFirstInFirstOut() {
		var emitter = new Emitter();
		var log = [];
		emitter.addEventListener(PING, function(_) log.push("a"));
		emitter.addEventListener(PING, function(_) log.push("b"));
		emitter.addEventListener(PING, function(_) log.push("c"));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("a,b,c", log.join(","));
	}

	function testAHigherPriorityRunsEarlierAndTiesKeepTheirOrder() {
		var emitter = new Emitter();
		var log = [];
		emitter.addEventListener(PING, function(_) log.push("zero"));
		emitter.addEventListener(PING, function(_) log.push("five"), 5);
		emitter.addEventListener(PING, function(_) log.push("minus"), -1);
		emitter.addEventListener(PING, function(_) log.push("five2"), 5);
		emitter.addEventListener(PING, function(_) log.push("zero2"));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("five,five2,zero,zero2,minus", log.join(","));
	}

	function testPrependGoesFirstAmongItsPriority() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("a"));
		emitter.on(PING, function(_) log.push("b"), 5);
		emitter.prepend(PING, function(_) log.push("c"));
		emitter.prepend(PING, function(_) log.push("d"), 5);
		emitter.prepend(PING, function(_) log.push("e"), -3);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("d,b,c,a,e", log.join(","));
	}

	function testAListenerAddedAgainIsIgnoredByDefault() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.addEventListener(PING, listener);
		emitter.addEventListener(PING, listener);
		emitter.on(PING, listener);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);

		emitter.removeEventListener(PING, listener);
		Assert.isFalse(emitter.hasEventListener(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnIgnoredDuplicateKeepsItsPlaceAndPriority() {
		var emitter = new Emitter();
		var log = [];
		var first = function(_:Event) log.push("first");
		emitter.addEventListener(PING, first);
		emitter.addEventListener(PING, function(_) log.push("second"));
		emitter.addEventListener(PING, first, 10);
		emitter.prepend(PING, first, 20);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("first,second", log.join(","));
	}

	function testOnceOfAListenerAlreadyThereIsIgnored() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.on(PING, listener);
		emitter.once(PING, listener);
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PING));
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
		emitter.addEventListener(PING, listener);
		emitter.addEventListener(PING, listener);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(2, calls);

		emitter.removeEventListener(PING, listener);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(3, calls);

		emitter.removeEventListener(PING, listener);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(3, calls);
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	function testTheDuplicatePolicyIsPerEmitter() {
		var keeping = new Emitter();
		keeping.allowDuplicates = true;
		var plain = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		keeping.addEventListener(PING, listener);
		keeping.addEventListener(PING, listener);
		plain.addEventListener(PING, listener);
		plain.addEventListener(PING, listener);
		keeping.dispatchEvent(new Event(PING));
		Assert.equals(2, calls);
		plain.dispatchEvent(new Event(PING));
		Assert.equals(3, calls);
	}

	function testRemovingWhatIsNotThereDoesNothing() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.removeEventListener(PING, listener);
		emitter.addEventListener(PING, listener);
		emitter.removeEventListener(PONG, listener);
		emitter.removeEventListener(PING, function(_) {});
		emitter.removeEventListener(PING, null);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
	}

	function testANullListenerOrTypeIsRefused() {
		var emitter = new Emitter();
		Assert.raises(() -> emitter.addEventListener(PING, null), haxe.exceptions.ArgumentException);
		Assert.raises(() -> emitter.addEventListener(null, function(_) {}), haxe.exceptions.ArgumentException);
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	function testRemoveEventListenersOfOneTypeOrAll() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("ping"));
		emitter.on(PING, function(_) log.push("ping2"));
		emitter.on(PONG, function(_) log.push("pong"));
		emitter.removeEventListeners(PING);
		Assert.isFalse(emitter.hasEventListener(PING));
		Assert.isTrue(emitter.hasEventListener(PONG));
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PONG));
		Assert.equals("pong", log.join(","));

		emitter.on(PING, function(_) log.push("again"));
		emitter.removeEventListeners();
		Assert.isFalse(emitter.hasEventListener(PING));
		Assert.isFalse(emitter.hasEventListener(PONG));
		Assert.isFalse(emitter.dispatchEvent(new Event(PING)));
		Assert.equals("pong", log.join(","));
	}

	function testRemoveAllListenersEmptiesBothLanes() {
		var emitter = new Emitter();
		var SIGNAL:Signal0 = "ping";
		emitter.on(PING, function(_) {});
		emitter.on(SIGNAL, function() {});
		emitter.removeAllListeners();
		Assert.isFalse(emitter.hasEventListener(PING));
		Assert.isFalse(emitter.hasSignalListener(SIGNAL));
		Assert.isFalse(emitter.emit(SIGNAL));
	}

	function testOnOffOnceAndPrependChainOnTheEmitter() {
		var emitter = new Emitter();
		var listener = function(_:Event) {};
		Assert.equals(emitter, emitter.on(PING, listener));
		Assert.equals(emitter, emitter.off(PING, listener));
		Assert.equals(emitter, emitter.once(PING, listener));
		Assert.equals(emitter, emitter.prepend(PONG, listener));
	}

	function testOnceRunsForTheNextEventOnly() {
		var emitter = new Emitter();
		var calls = 0;
		emitter.once(PING, function(_) calls++);
		Assert.isTrue(emitter.dispatchEvent(new Event(PING)));
		Assert.isFalse(emitter.dispatchEvent(new Event(PING)));
		Assert.equals(1, calls);
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	function testOffCancelsAOnceBeforeItRuns() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(_:Event) calls++;
		emitter.once(PING, listener);
		Assert.isTrue(emitter.has(PING, listener));
		emitter.off(PING, listener);
		Assert.isFalse(emitter.hasEventListener(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(0, calls);
	}

	function testAOnceListenerIsGoneWhileItRuns() {
		var emitter = new Emitter();
		var inside:Null<Bool> = null;
		var listener:Event->Void = null;
		listener = function(_:Event) inside = emitter.has(PING, listener);
		emitter.once(PING, listener);
		emitter.dispatchEvent(new Event(PING));
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
			emitter.dispatchEvent(new Event(PING));
		}
		Assert.equals(3, calls);
	}

	function testOnceKeepsItsPriority() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(PING, function(_) log.push("plain"));
		emitter.once(PING, function(_) log.push("once"), 1);
		emitter.dispatchEvent(new Event(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals("once,plain,plain", log.join(","));
	}

	function testHasEventListenerWithAListenerSaysWhetherThatOneListens() {
		var emitter = new Emitter();
		var a = function(_:Event) {};
		var b = function(_:Event) {};
		Assert.isFalse(emitter.has(PING, a));
		emitter.on(PING, a);
		Assert.isTrue(emitter.hasEventListener(PING));
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
			emitter.addEventListener(name, function(e:Event) heard.push(e.type));
		}
		for (i in 0...20) {
			Assert.isTrue(emitter.hasEventListener("type" + i));
			Assert.isTrue(emitter.dispatchEvent(new Event("type" + i)));
		}
		Assert.equals(20, heard.length);
		Assert.equals("type13", heard[13]);
		Assert.isFalse(emitter.hasEventListener("type20"));
		Assert.isFalse(emitter.dispatchEvent(new Event("type20")));

		for (i in 0...20) {
			emitter.removeEventListeners("type" + i);
			Assert.isFalse(emitter.hasEventListener("type" + i));
		}
		emitter.addEventListener("again", function(e:Event) heard.push(e.type));
		emitter.dispatchEvent(new Event("again"));
		Assert.equals("again", heard[20]);
	}

	function testRemovingAnyOfAFewTypesKeepsTheOthers() {
		// Within the chain natively and on JavaScript: the first type, one in
		// the middle and the last each go, and the rest are still found.
		var emitter = new Emitter();
		var heard = [];
		var listen = function(name:String) emitter.addEventListener(name, function(e:Event) heard.push(e.type));
		for (name in ["a", "b", "c", "d"]) {
			listen(name);
		}
		emitter.removeEventListeners("a");
		emitter.removeEventListeners("c");
		listen("e");
		emitter.removeEventListeners("e");
		listen("f");
		for (name in ["a", "b", "c", "d", "e", "f"]) {
			emitter.dispatchEvent(new Event(name));
		}
		Assert.equals("b,d,f", heard.join(","));
		emitter.removeEventListeners("b");
		emitter.removeEventListeners("d");
		emitter.removeEventListeners("f");
		Assert.isFalse(emitter.hasEventListener("b"));
		Assert.isFalse(emitter.hasEventListener("f"));
		listen("g");
		Assert.isTrue(emitter.dispatchEvent(new Event("g")));
		Assert.equals("b,d,f,g", heard.join(","));
	}

	function testATypeMadeAtRunTimeFindsTheListenersOfTheSameText() {
		// Natively types are compared by which string they are first: a
		// string built at run time is another one with the same text.
		var emitter = new Emitter();
		var calls = 0;
		emitter.addEventListener("change", function(_) calls++);
		emitter.addEventListener("other", function(_) {});
		var built = ["ch", "ange"].join("");
		Assert.isTrue(emitter.hasEventListener(built));
		Assert.isTrue(emitter.dispatchEvent(new Event(built)));
		Assert.equals(1, calls);
		emitter.removeEventListeners(built);
		Assert.isFalse(emitter.hasEventListener("change"));
	}

	function testDispatchSaysWhetherAnythingListened() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.dispatchEvent(new Event(PING)));
		emitter.on(PONG, function(_) {});
		Assert.isFalse(emitter.dispatchEvent(new Event(PING)));
		Assert.isTrue(emitter.dispatchEvent(new Event(PONG)));
		Assert.isFalse(emitter.dispatchEvent(null));
	}

	function testListenersOfOneEmitterAreNotAnothers() {
		var a = new Emitter();
		var b = new Emitter();
		var calls = 0;
		a.on(PING, function(_) calls++);
		Assert.isFalse(b.hasEventListener(PING));
		Assert.isFalse(b.dispatchEvent(new Event(PING)));
		Assert.equals(0, calls);
	}

	function testAnIEmitterTakesListenersAndEvents() {
		var holder = new Holder();
		var target:Null<IEmitter> = null;
		var listener = function(e:Event) target = e.target;
		var asInterface:IEmitter = holder;
		asInterface.addEventListener(PING, listener);
		Assert.isTrue(asInterface.hasEventListener(PING));
		Assert.isTrue(asInterface.dispatchEvent(new Event(PING)));
		Assert.equals(asInterface, target);
		asInterface.removeEventListener(PING, listener);
		Assert.isFalse(asInterface.hasEventListener(PING));
	}
}
