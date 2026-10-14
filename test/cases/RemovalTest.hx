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
		emitter.addEventListener(PING, onPing);
		Assert.isTrue(emitter.has(PING, onPing));
		emitter.removeEventListener(PING, onPing);
		Assert.isFalse(emitter.hasEventListener(PING));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(0, calls);

		emitter.on(PING, this.onPing);
		emitter.off(PING, this.onPing);
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	function testABoundMethodAddedTwiceIsOneListener() {
		var emitter = new Emitter();
		emitter.addEventListener(PING, onPing);
		emitter.addEventListener(PING, onPing);
		emitter.on(PING, this.onPing);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
	}

	function testAnotherInstancesMethodIsAnotherListener() {
		var emitter = new Emitter();
		var other = new RemovalTest();
		emitter.addEventListener(PING, onPing);
		emitter.addEventListener(PING, other.onPing);
		emitter.removeEventListener(PING, other.onPing);
		Assert.isTrue(emitter.has(PING, onPing));
		Assert.isFalse(emitter.has(PING, other.onPing));
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, calls);
		Assert.equals(0, other.calls);
	}

	function testABoundMethodOnASignalIsRemovedByReadingItAgain() {
		var emitter = new Emitter();
		emitter.on(VALUE, onSignal);
		Assert.isTrue(emitter.has(VALUE, onSignal));
		emitter.off(VALUE, onSignal);
		Assert.isFalse(emitter.hasSignalListener(VALUE));
		emitter.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testABoundMethodOnceIsCancelledByReadingItAgain() {
		var emitter = new Emitter();
		emitter.once(PING, onPing);
		emitter.off(PING, onPing);
		emitter.once(VALUE, onSignal);
		emitter.off(VALUE, onSignal);
		emitter.dispatchEvent(new Event(PING));
		emitter.emit(VALUE, 5);
		Assert.equals(0, calls);
	}

	function testATypedListenerIsFoundWhicheverWayItWasAdded() {
		// Each way to add, then each way to remove: on HashLink a typed
		// function passed through a generic signature is stored wrapped.
		var listener = function(event:ValueEvent):Void calls += event.value;
		var adds:Array<Emitter->Void> = [
			e -> e.addEventListener(ValueEvent.VALUE, listener),
			e -> e.on(ValueEvent.VALUE, listener),
			e -> e.prepend(ValueEvent.VALUE, listener),
			e -> e.once(ValueEvent.VALUE, listener)
		];
		var removes:Array<Emitter->Void> = [
			e -> e.removeEventListener(ValueEvent.VALUE, listener),
			e -> e.off(ValueEvent.VALUE, listener)
		];
		for (add in adds) {
			for (remove in removes) {
				var emitter = new Emitter();
				add(emitter);
				add(emitter);
				Assert.isTrue(emitter.has(ValueEvent.VALUE, listener));
				remove(emitter);
				Assert.isFalse(emitter.hasEventListener(ValueEvent.VALUE));
				emitter.dispatchEvent(new ValueEvent(ValueEvent.VALUE, 1));
			}
		}
		Assert.equals(0, calls);
	}

	function testABoundTypedMethodIsFoundWhicheverWayItWasAdded() {
		var emitter = new Emitter();
		emitter.addEventListener(ValueEvent.VALUE, onValue);
		emitter.on(ValueEvent.VALUE, onValue);
		emitter.prepend(ValueEvent.VALUE, onValue);
		emitter.dispatchEvent(new ValueEvent(ValueEvent.VALUE, 2));
		Assert.equals(2, calls);
		emitter.off(ValueEvent.VALUE, onValue);
		Assert.isFalse(emitter.hasEventListener(ValueEvent.VALUE));
	}

	function testAListenerForTheBaseEventIsFoundOnASubtypesType() {
		var emitter = new Emitter();
		var general:Event->Void = function(_:Event) calls++;
		emitter.addEventListener(ValueEvent.VALUE, general);
		emitter.addEventListener(ValueEvent.VALUE, general);
		emitter.dispatchEvent(new ValueEvent(ValueEvent.VALUE, 1));
		Assert.equals(1, calls);
		Assert.isTrue(emitter.has(ValueEvent.VALUE, general));
		emitter.removeEventListener(ValueEvent.VALUE, general);
		Assert.isFalse(emitter.hasEventListener(ValueEvent.VALUE));
	}

	function testALocalFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		var a = function(_:Event) calls++;
		var b = function(_:Event) calls += 10;
		emitter.on(PING, a).on(PING, b);
		emitter.off(PING, a);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(10, calls);
	}

	function testAStaticFunctionIsRemovedByItself() {
		var emitter = new Emitter();
		staticCalls = 0;
		emitter.on(PING, onStaticPing);
		emitter.on(PING, RemovalTest.onStaticPing);
		emitter.dispatchEvent(new Event(PING));
		emitter.off(PING, onStaticPing);
		emitter.dispatchEvent(new Event(PING));
		Assert.equals(1, staticCalls);
		Assert.isFalse(emitter.hasEventListener(PING));
	}

	static var staticCalls:Int = 0;

	static function onStaticPing(_:Event):Void {
		staticCalls++;
	}
}
