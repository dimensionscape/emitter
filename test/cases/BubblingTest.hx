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
		leaf.on(PING, record(leaf));
		mid.on(PING, record(mid));
		root.on(PING, record(root));
		Assert.isTrue(leaf.dispatchEvent(new Event(PING, true)));
		Assert.equals("leaf:leaf>leaf,mid:leaf>mid,root:leaf>root", log.join(","));
	}

	function testAnEventThatDoesNotBubbleNeverAsksForAParent() {
		leaf.on(PING, record(leaf));
		root.on(PING, record(root));
		leaf.dispatchEvent(new Event(PING));
		Assert.equals("leaf:leaf>leaf", log.join(","));
		Assert.equals(0, leaf.parentReads);
		Assert.equals(0, mid.parentReads);
	}

	function testABubblingEventAsksEachEmitterOnceForItsParent() {
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals(1, leaf.parentReads);
		Assert.equals(1, mid.parentReads);
		Assert.equals(1, root.parentReads);
	}

	function testStopPropagationLetsTheEmitterFinishAndGoesNoHigher() {
		leaf.on(PING, record(leaf));
		mid.on(PING, function(e:Event) {
			log.push("mid");
			e.stopPropagation();
		});
		mid.on(PING, function(_) log.push("mid2"));
		root.on(PING, record(root));
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("leaf:leaf>leaf,mid,mid2", log.join(","));
		Assert.equals(0, mid.parentReads);
	}

	function testStopImmediatePropagationStopsEverythingAfterIt() {
		mid.on(PING, function(e:Event) {
			log.push("mid");
			e.stopImmediatePropagation();
		});
		mid.on(PING, function(_) log.push("mid2"));
		root.on(PING, record(root));
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("mid", log.join(","));
	}

	function testDispatchSaysWhetherAnyEmitterOnTheWayListened() {
		Assert.isFalse(leaf.dispatchEvent(new Event(PING, true)));
		root.on(PING, record(root));
		Assert.isTrue(leaf.dispatchEvent(new Event(PING, true)));
		Assert.isFalse(leaf.dispatchEvent(new Event(PING)));
	}

	function testCurrentTargetIsOnlySetWhereListenersRun() {
		root.on(PING, record(root));
		var event = new Event(PING, true);
		leaf.dispatchEvent(event);
		Assert.equals((root : IEmitter), event.currentTarget);
	}

	function testAnEmitterWithADelegateIsItsDelegateOnTheWay() {
		var holder = new Holder();
		var middle = new Node("middle", root, holder);
		var bottom = new Node("bottom", middle);
		var seen:Null<IEmitter> = null;
		middle.on(PING, function(e:Event) seen = e.currentTarget);
		bottom.dispatchEvent(new Event(PING, true));
		Assert.equals((holder : IEmitter), seen);
	}

	function testAListenerAddedToAParentDuringTheBubbleRunsForIt() {
		leaf.on(PING, function(_) {
			log.push("leaf");
			root.on(PING, function(_) log.push("root, added on the way"));
		});
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("leaf,root, added on the way", log.join(","));
	}

	function testAListenerAddedToTheSameEmitterDuringTheBubbleWaits() {
		leaf.on(PING, function(_) {
			log.push("leaf");
			leaf.on(PING, function(_) log.push("leaf, added"));
		});
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("leaf", log.join(","));
		log = [];
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("leaf,leaf, added", log.join(","));
	}

	function testAListenerRemovedFromAParentBeforeTheEventGetsThereDoesNotRun() {
		var rootListener = function(_:Event) log.push("root");
		root.on(PING, rootListener);
		leaf.on(PING, function(_) root.off(PING, rootListener));
		leaf.dispatchEvent(new Event(PING, true));
		Assert.equals("", log.join(","));
	}

	function testBubblingStartsFromTheEmitterDispatchingNotAGivenTarget() {
		var elsewhere = new Node("elsewhere");
		mid.on(PING, record(mid));
		root.on(PING, record(root));
		var event = new Event(PING, true);
		@:privateAccess event.target = elsewhere;
		mid.dispatchEvent(event);
		Assert.equals("mid:elsewhere>mid,root:elsewhere>root", log.join(","));
		Assert.equals(0, elsewhere.parentReads);
	}

	function testAThrowOnTheWayReachesTheCaller() {
		mid.on(PING, function(_) throw "mid");
		root.on(PING, record(root));
		var caught:Dynamic = null;
		try {
			leaf.dispatchEvent(new Event(PING, true));
		} catch (e:Dynamic) {
			caught = e;
		}
		Assert.equals("mid", caught);
		Assert.equals("", log.join(","));
	}

	function testAnEmitterWithoutListenersPassesTheEventOn() {
		var quietMiddle = new Node("quiet", root);
		var bottom = new Node("bottom", quietMiddle);
		root.on(PING, record(root));
		bottom.dispatchEvent(new Event(PING, true));
		Assert.equals("root:bottom>root", log.join(","));
	}
}
