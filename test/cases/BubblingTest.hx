package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import support.Support;
import utest.Assert;
import utest.Test;

/** Events going up through getEventParent. **/
class BubblingTest extends Test {
	static inline var PING:EventType<Event> = "ping";

	var root:Node;
	var mid:Node;
	var leaf:Node;
	var log:Array<String>;

	function setup() {
		root = new Node("root");
		mid = new Node("mid", root);
		leaf = new Node("leaf", mid);
		log = [];
	}

	function record(node:Node):Event->Void {
		return function(e:Event) log.push(node.name + ":" + Std.string(e.target) + ">" + Std.string(e.currentTarget));
	}

	function testABubblingEventRunsEachEmitterUpTheChainInTurn() {
		leaf.events.on(PING, record(leaf));
		mid.events.on(PING, record(mid));
		root.events.on(PING, record(root));
		Assert.isTrue(leaf.events.dispatch(new Event(PING, true)));
		Assert.equals("leaf:leaf>leaf,mid:leaf>mid,root:leaf>root", log.join(","));
	}

	function testAnEventThatDoesNotBubbleNeverAsksForAParent() {
		leaf.events.on(PING, record(leaf));
		root.events.on(PING, record(root));
		leaf.events.dispatch(new Event(PING));
		Assert.equals("leaf:leaf>leaf", log.join(","));
		Assert.equals(0, leaf.parentReads);
		Assert.equals(0, mid.parentReads);
	}

	function testABubblingEventAsksEachEmitterOnceForItsParent() {
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals(1, leaf.parentReads);
		Assert.equals(1, mid.parentReads);
		Assert.equals(1, root.parentReads);
	}

	function testStopPropagationLetsTheEmitterFinishAndGoesNoHigher() {
		leaf.events.on(PING, record(leaf));
		mid.events.on(PING, function(e:Event) {
			log.push("mid");
			e.stopPropagation();
		});
		mid.events.on(PING, function(_) log.push("mid2"));
		root.events.on(PING, record(root));
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("leaf:leaf>leaf,mid,mid2", log.join(","));
		Assert.equals(0, mid.parentReads);
	}

	function testStopImmediatePropagationStopsEverythingAfterIt() {
		mid.events.on(PING, function(e:Event) {
			log.push("mid");
			e.stopImmediatePropagation();
		});
		mid.events.on(PING, function(_) log.push("mid2"));
		root.events.on(PING, record(root));
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("mid", log.join(","));
	}

	function testDispatchSaysWhetherAnyEmitterOnTheWayListened() {
		Assert.isFalse(leaf.events.dispatch(new Event(PING, true)));
		root.events.on(PING, record(root));
		Assert.isTrue(leaf.events.dispatch(new Event(PING, true)));
		Assert.isFalse(leaf.events.dispatch(new Event(PING)));
	}

	function testCurrentTargetIsOnlySetWhereListenersRun() {
		root.events.on(PING, record(root));
		var event = new Event(PING, true);
		leaf.events.dispatch(event);
		Assert.equals((root : IEmitter), event.currentTarget);
	}

	function testAnEmitterWithADelegateIsItsDelegateOnTheWay() {
		var holder = new Holder();
		var middle = new Node("middle", root, holder);
		var bottom = new Node("bottom", middle);
		var seen:Null<IEmitter> = null;
		middle.events.on(PING, function(e:Event) seen = e.currentTarget);
		bottom.events.dispatch(new Event(PING, true));
		Assert.equals((holder : IEmitter), seen);
	}

	function testAListenerAddedToAParentDuringTheBubbleRunsForIt() {
		leaf.events.on(PING, function(_) {
			log.push("leaf");
			root.events.on(PING, function(_) log.push("root, added on the way"));
		});
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("leaf,root, added on the way", log.join(","));
	}

	function testAListenerAddedToTheSameEmitterDuringTheBubbleWaits() {
		leaf.events.on(PING, function(_) {
			log.push("leaf");
			leaf.events.on(PING, function(_) log.push("leaf, added"));
		});
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("leaf", log.join(","));
		log = [];
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("leaf,leaf, added", log.join(","));
	}

	function testAListenerRemovedFromAParentBeforeTheEventGetsThereDoesNotRun() {
		var rootListener = function(_:Event) log.push("root");
		root.events.on(PING, rootListener);
		leaf.events.on(PING, function(_) root.events.off(PING, rootListener));
		leaf.events.dispatch(new Event(PING, true));
		Assert.equals("", log.join(","));
	}

	function testBubblingStartsFromTheEmitterDispatchingNotAGivenTarget() {
		var elsewhere = new Node("elsewhere");
		mid.events.on(PING, record(mid));
		root.events.on(PING, record(root));
		var event = new Event(PING, true);
		@:privateAccess event.target = elsewhere;
		mid.events.dispatch(event);
		Assert.equals("mid:elsewhere>mid,root:elsewhere>root", log.join(","));
		Assert.equals(0, elsewhere.parentReads);
	}

	function testAThrowOnTheWayReachesTheCaller() {
		mid.events.on(PING, function(_) throw "mid");
		root.events.on(PING, record(root));
		var caught:Dynamic = null;
		try {
			leaf.events.dispatch(new Event(PING, true));
		} catch (e:Dynamic) {
			caught = e;
		}
		Assert.equals("mid", caught);
		Assert.equals("", log.join(","));
	}

	function testAnEmitterWithoutListenersPassesTheEventOn() {
		var quietMiddle = new Node("quiet", root);
		var bottom = new Node("bottom", quietMiddle);
		root.events.on(PING, record(root));
		bottom.events.dispatch(new Event(PING, true));
		Assert.equals("root:bottom>root", log.join(","));
	}
}
