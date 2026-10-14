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
		emitter.on(PING, onPing);
		Assert.isTrue(emitter.has(PING, onPing));
		emitter.off(PING, onPing);
		Assert.isFalse(emitter.has(PING));
		emitter.dispatch(new Event(PING));
		Assert.equals(0, calls);

		emitter.on(PING, this.onPing);
		emitter.off(PING, this.onPing);
		Assert.isFalse(emitter.has(PING));
	}

	function testABoundMethodAddedTwiceIsOneListener() {
		var emitter = new Emitter();
		emitter.on(PING, onPing);
		emitter.on(PING, onPing);
		emitter.on(PING, this.onPing);
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnotherInstancesMethodIsAnotherListener() {
		var emitter = new Emitter();
		var other = new RemovalTest();
		emitter.on(PING, onPing);
		emitter.on(PING, other.onPing);
		emitter.off(PING, other.onPing);
		Assert.isTrue(emitter.has(PING, onPing));
		Assert.isFalse(emitter.has(PING, other.onPing));
		emitter.dispatch(new Event(PING));
		Assert.equals(1, calls);
		Assert.equals(0, other.calls);
	}

	function testABoundMethodOnASignalIsRemovedByReadingItAgain() {
		var emitter = new Emitter();
		emitter.on(VALUE, onSignal);
		Assert.isTrue(emitter.has(VALUE, onSignal));
		emitter.off(VALUE, onSignal);
		Assert.isFalse(emitter.has(VALUE));
		emitter.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testABoundMethodOnceIsCancelledByReadingItAgain() {
		var emitter = new Emitter();
		emitter.once(PING, onPing);
		emitter.off(PING, onPing);
		emitter.once(VALUE, onSignal);
		emitter.off(VALUE, onSignal);
		emitter.dispatch(new Event(PING));
		emitter.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testATypedListenerIsFoundWhicheverWayItWasAdded() {
		// Each way to add, then each way to remove, a framework's names
		// included: on HashLink a typed function passed through a generic
		// signature is stored wrapped.
		var listener = function(event:ValueEvent):Void calls += event.value;
		var adds:Array<FlashDispatcher->Void> = [
			e -> e.on(ValueEvent.VALUE, listener),
			e -> e.on(ValueEvent.VALUE, listener, 4),
			e -> e.once(ValueEvent.VALUE, listener),
			e -> e.addEventListener(ValueEvent.VALUE, listener)
		];
		var removes:Array<FlashDispatcher->Void> = [
			e -> e.off(ValueEvent.VALUE, listener),
			e -> e.removeEventListener(ValueEvent.VALUE, listener)
		];
		for (add in adds) {
			for (remove in removes) {
				var emitter = new FlashDispatcher();
				add(emitter);
				add(emitter);
				Assert.isTrue(emitter.has(ValueEvent.VALUE, listener));
				remove(emitter);
				Assert.isFalse(emitter.has(ValueEvent.VALUE));
				emitter.dispatch(new ValueEvent(ValueEvent.VALUE, 1));
			}
		}
		Assert.equals(0, calls);
	}

	function testABoundTypedMethodIsFoundWhicheverWayItWasAdded() {
		var emitter = new Emitter();
		emitter.on(ValueEvent.VALUE, onValue);
		emitter.on(ValueEvent.VALUE, onValue);
		emitter.once(ValueEvent.VALUE, onValue);
		emitter.dispatch(new ValueEvent(ValueEvent.VALUE, 2));
		Assert.equals(2, calls);
		emitter.off(ValueEvent.VALUE, onValue);
		Assert.isFalse(emitter.has(ValueEvent.VALUE));
	}

	function testAListenerForTheBaseEventIsFoundOnASubtypesType() {
		var emitter = new Emitter();
		var general:Event->Void = function(_:Event) calls++;
		emitter.on(ValueEvent.VALUE, general);
		emitter.on(ValueEvent.VALUE, general);
		emitter.dispatch(new ValueEvent(ValueEvent.VALUE, 1));
		Assert.equals(1, calls);
		Assert.isTrue(emitter.has(ValueEvent.VALUE, general));
		emitter.off(ValueEvent.VALUE, general);
		Assert.isFalse(emitter.has(ValueEvent.VALUE));
	}

	function testALocalFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		var a = function(_:Event) calls++;
		var b = function(_:Event) calls += 10;
		emitter.on(PING, a);
		emitter.on(PING, b);
		emitter.off(PING, a);
		emitter.dispatch(new Event(PING));
		Assert.equals(10, calls);
	}

	function testAStaticFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		staticCalls = 0;
		emitter.on(PING, onStaticPing);
		emitter.on(PING, RemovalTest.onStaticPing);
		emitter.dispatch(new Event(PING));
		emitter.off(PING, onStaticPing);
		emitter.dispatch(new Event(PING));
		Assert.equals(1, staticCalls);
		Assert.isFalse(emitter.has(PING));
	}

	static var staticCalls:Int = 0;

	static function onStaticPing(_:Event):Void {
		staticCalls++;
	}
}
