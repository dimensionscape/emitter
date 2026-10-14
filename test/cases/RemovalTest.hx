package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal1;
import support.Support;
import utest.Assert;
import utest.Test;

/**
	Finding a listener again to remove it, on every target: bound methods
	(a new closure on each read on eval, neko and the jvm) and typed
	functions passed through a generic signature (wrapped on HashLink).
**/
class RemovalTest extends Test {
	static inline var PING:EventType<Event> = "ping";
	static inline var VALUE:Signal1<Int> = "value";

	var calls:Int = 0;

	function onPing(_:Event):Void {
		calls++;
	}

	function onValue(event:ValueEvent):Void {
		calls += event.value;
	}

	function onSignal(value:Int):Void {
		calls += value;
	}

	function setup() {
		calls = 0;
	}

	function testABoundMethodIsRemovedByReadingItAgain() {
		var emitter = new Emitter();
		emitter.events.on(PING, onPing);
		Assert.isTrue(emitter.events.has(PING, onPing));
		emitter.events.off(PING, onPing);
		Assert.isFalse(emitter.events.has(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(0, calls);

		emitter.events.on(PING, this.onPing);
		emitter.events.off(PING, this.onPing);
		Assert.isFalse(emitter.events.has(PING));
	}

	function testABoundMethodAddedTwiceIsOneListener() {
		var emitter = new Emitter();
		emitter.events.on(PING, onPing);
		emitter.events.on(PING, onPing);
		emitter.events.on(PING, this.onPing);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnotherInstancesMethodIsAnotherListener() {
		var emitter = new Emitter();
		var other = new RemovalTest();
		emitter.events.on(PING, onPing);
		emitter.events.on(PING, other.onPing);
		emitter.events.off(PING, other.onPing);
		Assert.isTrue(emitter.events.has(PING, onPing));
		Assert.isFalse(emitter.events.has(PING, other.onPing));
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, calls);
		Assert.equals(0, other.calls);
	}

	function testABoundMethodOnASignalIsRemovedByReadingItAgain() {
		var emitter = new Emitter();
		emitter.events.on(VALUE, onSignal);
		Assert.isTrue(emitter.events.has(VALUE, onSignal));
		emitter.events.off(VALUE, onSignal);
		Assert.isFalse(emitter.events.has(VALUE));
		emitter.events.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testABoundMethodOnceIsCancelledByReadingItAgain() {
		var emitter = new Emitter();
		emitter.events.once(PING, onPing);
		emitter.events.off(PING, onPing);
		emitter.events.once(VALUE, onSignal);
		emitter.events.off(VALUE, onSignal);
		emitter.events.dispatch(new Event(PING));
		emitter.events.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testATypedListenerIsFoundWhicheverWayItWasAdded() {
		// Each way to add, then each way to remove, a framework's names
		// included: on HashLink a typed function passed through a generic
		// signature is stored wrapped.
		var listener = function(event:ValueEvent):Void calls += event.value;
		var adds:Array<FlashDispatcher->Void> = [
			e -> e.events.on(ValueEvent.VALUE, listener),
			e -> e.events.on(ValueEvent.VALUE, listener, 4),
			e -> e.events.once(ValueEvent.VALUE, listener),
			e -> e.addEventListener(ValueEvent.VALUE, listener)
		];
		var removes:Array<FlashDispatcher->Void> = [
			e -> e.events.off(ValueEvent.VALUE, listener),
			e -> e.removeEventListener(ValueEvent.VALUE, listener)
		];
		for (add in adds) {
			for (remove in removes) {
				var emitter = new FlashDispatcher();
				add(emitter);
				add(emitter);
				Assert.isTrue(emitter.events.has(ValueEvent.VALUE, listener));
				remove(emitter);
				Assert.isFalse(emitter.events.has(ValueEvent.VALUE));
				emitter.events.dispatch(new ValueEvent(ValueEvent.VALUE, 1));
			}
		}
		Assert.equals(0, calls);
	}

	function testABoundTypedMethodIsFoundWhicheverWayItWasAdded() {
		var emitter = new Emitter();
		emitter.events.on(ValueEvent.VALUE, onValue);
		emitter.events.on(ValueEvent.VALUE, onValue);
		emitter.events.once(ValueEvent.VALUE, onValue);
		emitter.events.dispatch(new ValueEvent(ValueEvent.VALUE, 2));
		Assert.equals(2, calls);
		emitter.events.off(ValueEvent.VALUE, onValue);
		Assert.isFalse(emitter.events.has(ValueEvent.VALUE));
	}

	function testAListenerForTheBaseEventIsFoundOnASubtypesType() {
		var emitter = new Emitter();
		var general:Event->Void = function(_:Event) calls++;
		emitter.events.on(ValueEvent.VALUE, general);
		emitter.events.on(ValueEvent.VALUE, general);
		emitter.events.dispatch(new ValueEvent(ValueEvent.VALUE, 1));
		Assert.equals(1, calls);
		Assert.isTrue(emitter.events.has(ValueEvent.VALUE, general));
		emitter.events.off(ValueEvent.VALUE, general);
		Assert.isFalse(emitter.events.has(ValueEvent.VALUE));
	}

	function testALocalFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		var a = function(_:Event) calls++;
		var b = function(_:Event) calls += 10;
		emitter.events.on(PING, a);
		emitter.events.on(PING, b);
		emitter.events.off(PING, a);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(10, calls);
	}

	function testAStaticFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		staticCalls = 0;
		emitter.events.on(PING, onStaticPing);
		emitter.events.on(PING, RemovalTest.onStaticPing);
		emitter.events.dispatch(new Event(PING));
		emitter.events.off(PING, onStaticPing);
		emitter.events.dispatch(new Event(PING));
		Assert.equals(1, staticCalls);
		Assert.isFalse(emitter.events.has(PING));
	}

	static var staticCalls:Int = 0;

	static function onStaticPing(_:Event):Void {
		staticCalls++;
	}
}
