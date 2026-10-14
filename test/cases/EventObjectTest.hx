package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import support.Support;
import utest.Assert;
import utest.Test;

/** The `Event` class on its own. **/
class EventObjectTest extends Test {
	function testANewEventSaysOnlyWhatItWasMadeWith() {
		var event = new Event("ping");
		Assert.equals("ping", event.type);
		Assert.isFalse(event.bubbles);
		Assert.isFalse(event.cancelable);
		Assert.isFalse(event.defaultPrevented);
		Assert.isNull(event.target);
		Assert.isNull(event.currentTarget);
		Assert.isFalse(event.propagationStopped);
		Assert.isFalse(event.immediatePropagationStopped);

		var both = new Event("ping", true, true);
		Assert.isTrue(both.bubbles);
		Assert.isTrue(both.cancelable);
	}

	function testPreventDefaultOnlyCountsWhenCancelable() {
		var plain = new Event("x");
		plain.preventDefault();
		Assert.isFalse(plain.defaultPrevented);

		var cancelable = new Event("x", false, true);
		cancelable.preventDefault();
		Assert.isTrue(cancelable.defaultPrevented);
	}

	function testStopPropagationSetsOnlyItsOwnFlag() {
		var event = new Event("x");
		event.stopPropagation();
		Assert.isTrue(event.propagationStopped);
		Assert.isFalse(event.immediatePropagationStopped);
	}

	function testStopImmediatePropagationSetsBothFlags() {
		var event = new Event("x");
		event.stopImmediatePropagation();
		Assert.isTrue(event.propagationStopped);
		Assert.isTrue(event.immediatePropagationStopped);
	}

	function testReuseClearsWhatADispatchLeftAndKeepsWhatItIs() {
		var emitter = new Emitter();
		emitter.on("x", function(e:Event) {
			e.preventDefault();
			e.stopImmediatePropagation();
		});
		var event = new Event("x", true, true);
		emitter.dispatch(event);
		Assert.equals((emitter : IEmitter), event.target);
		Assert.isTrue(event.defaultPrevented);
		Assert.isTrue(event.propagationStopped);

		event.reuse();
		Assert.isNull(event.target);
		Assert.isNull(event.currentTarget);
		Assert.isFalse(event.defaultPrevented);
		Assert.isFalse(event.propagationStopped);
		Assert.isFalse(event.immediatePropagationStopped);
		Assert.equals("x", event.type);
		Assert.isTrue(event.bubbles);
		Assert.isTrue(event.cancelable);
	}

	function testCloneCopiesWhatTheEventSaysButNotTheStopFlags() {
		var emitter = new Emitter();
		emitter.on("x", function(e:Event) {
			e.preventDefault();
			e.stopPropagation();
		});
		var event = new Event("x", true, true);
		emitter.dispatch(event);

		var copy = event.clone();
		Assert.notEquals(event, copy);
		Assert.equals("x", copy.type);
		Assert.isTrue(copy.bubbles);
		Assert.isTrue(copy.cancelable);
		Assert.isTrue(copy.defaultPrevented);
		Assert.equals(event.target, copy.target);
		Assert.equals(event.currentTarget, copy.currentTarget);
		Assert.isFalse(copy.propagationStopped);
	}

	function testToStringNamesTheEvent() {
		Assert.equals('[Event type="change" bubbles=true cancelable=false]', new Event("change", true).toString());
	}

	function testTheGenericConstantsAreTheirNames() {
		Assert.equals("change", (Event.CHANGE : String));
		Assert.equals("complete", (Event.COMPLETE : String));
		Assert.equals("close", (Event.CLOSE : String));
		Assert.equals("cancel", (Event.CANCEL : String));
	}

	function testAnEventTypeComparesAsItsString() {
		var type:EventType<ValueEvent> = "value";
		Assert.isTrue(type == "value");
		Assert.isFalse(type != "value");
		Assert.isTrue(ValueEvent.VALUE == type);
	}

	function testTargetIsTypedAsAnEmitter() {
		var node = new Node("leaf");
		var seen:Null<IEmitter> = null;
		node.on(Event.CHANGE, function(e:Event) seen = e.target);
		node.dispatch(new Event(Event.CHANGE));
		Assert.equals((node : IEmitter), seen);
		Assert.isTrue(Std.isOfType(seen, Node));
		var back:Node = cast seen;
		Assert.equals("leaf", back.name);
	}
}
