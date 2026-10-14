package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import haxe.CallStack;
import support.Support;
import utest.Assert;
import utest.Test;

/** dispatchEvent, dispatchLocal and dispatchContained on one emitter. **/
class DispatchTest extends Test {
	static inline var PING:EventType<Event> = "ping";

	function testDispatchSetsTargetAndCurrentTarget() {
		var emitter = new Emitter();
		var target:Null<IEmitter> = null;
		var current:Null<IEmitter> = null;
		emitter.events.on(PING, function(e:Event) {
			target = e.target;
			current = e.currentTarget;
		});
		emitter.events.dispatch(new Event(PING));
		Assert.equals((emitter : IEmitter), target);
		Assert.equals((emitter : IEmitter), current);
	}

	function testWithNoListenersTheTargetIsStillSet() {
		var emitter = new Emitter();
		var event = new Event(PING);
		Assert.isFalse(emitter.events.dispatch(event));
		Assert.equals((emitter : IEmitter), event.target);
	}

	function testADelegateTargetStandsInForTheEmitter() {
		var holder = new Holder();
		var target:Null<IEmitter> = null;
		var current:Null<IEmitter> = null;
		holder.events.on(PING, function(e:Event) {
			target = e.target;
			current = e.currentTarget;
		});
		holder.events.dispatch(new Event(PING));
		Assert.equals((holder : IEmitter), target);
		Assert.equals((holder : IEmitter), current);

		var quiet = new Event(PING, true);
		holder.emitter.events.clear();
		holder.events.dispatch(quiet);
		Assert.equals((holder : IEmitter), quiet.target);
	}

	function testAnEventHandedOnKeepsItsTargetAndGetsItsCurrentTargetBack() {
		var first = new Emitter();
		var second = new Emitter();
		var seen = [];
		first.events.on(PING, function(e:Event) {
			seen.push("first:" + (e.currentTarget == first));
			second.events.dispatch(e);
		});
		first.events.on(PING, function(e:Event) seen.push("after:" + (e.target == first) + "," + (e.currentTarget == first)));
		second.events.on(PING, function(e:Event) seen.push("second:" + (e.target == first) + "," + (e.currentTarget == second)));
		first.events.dispatch(new Event(PING));
		Assert.equals("first:true,second:true,true,after:true,true", seen.join(","));
	}

	function testAnEventHandedOnGetsItsCurrentTargetBackWhenAListenerThrows() {
		var first = new Emitter();
		var second = new Emitter();
		second.events.on(PING, function(_) throw "boom");
		var after:Null<IEmitter> = null;
		first.events.on(PING, function(e:Event) {
			try {
				second.events.dispatch(e);
			} catch (_:Dynamic) {}
			after = e.currentTarget;
		});
		first.events.dispatch(new Event(PING));
		Assert.equals((first : IEmitter), after);
	}

	function testStopImmediatePropagationSkipsTheRest() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(e:Event) {
			log.push("a");
			e.stopImmediatePropagation();
		});
		emitter.events.on(PING, function(_) log.push("b"));
		Assert.isTrue(emitter.events.dispatch(new Event(PING)));
		Assert.equals("a", log.join(","));
	}

	function testStopPropagationLetsThisEmittersListenersFinish() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(e:Event) {
			log.push("a");
			e.stopPropagation();
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b", log.join(","));
	}

	function testPreventDefaultReachesTheDispatcher() {
		var emitter = new Emitter();
		emitter.events.on(PING, function(e:Event) e.preventDefault());
		var event = new Event(PING, false, true);
		emitter.events.dispatch(event);
		Assert.isTrue(event.defaultPrevented);
	}

	function testAThrowFromTheOnlyListenerReachesTheCallerUntouched() {
		var emitter = new Emitter();
		var thrown = new haxe.Exception("only");
		emitter.events.on(PING, function(_) throw thrown);
		var caught:Null<haxe.Exception> = null;
		try {
			emitter.events.dispatch(new Event(PING));
		} catch (e:haxe.Exception) {
			caught = e;
		}
		Assert.equals(thrown, caught);
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testAThrowFromOneOfManyReachesTheCallerAndTheCountIsPutBack() {
		var emitter = new Emitter();
		var thrown = new haxe.Exception("second");
		var log = [];
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.on(PING, function(_) throw thrown);
		emitter.events.on(PING, function(_) log.push("c"));
		var caught:Null<haxe.Exception> = null;
		try {
			emitter.events.dispatch(new Event(PING));
		} catch (e:haxe.Exception) {
			caught = e;
		}
		Assert.equals(thrown, caught);
		Assert.equals("a", log.join(","));
		Assert.equals(0, Inside.eventWalks(emitter));

		// Left as it was: a removal from inside the next dispatch still lets
		// the removed listener run for it, and a later one does not.
		emitter.events.clear();
		var late = function(_:Event) log.push("late");
		emitter.events.on(PING, function(_) emitter.events.off(PING, late));
		emitter.events.on(PING, late);
		emitter.events.dispatch(new Event(PING));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,late", log.join(","));
	}

	function testAThrownValueThatIsNotAnExceptionIsRethrownAsItself() {
		var emitter = new Emitter();
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PING, function(_) throw "plain");
		var caught:Dynamic = null;
		try {
			emitter.events.dispatch(new Event(PING));
		} catch (e:Dynamic) {
			caught = e;
		}
		Assert.equals("plain", caught);
	}

	function testARethrownValueKeepsTheStackItWasThrownFrom() {
		// A plain value carries no stack of its own: what the caller reads is
		// the target's, which a rethrow keeps and a new throw would replace
		// with the dispatch's. Neko's stacks name no functions, and eval keeps
		// none across a rethrow; there only the value is checked.
		for (listeners in [1, 3]) {
			var emitter = new Emitter();
			for (_ in 1...listeners) {
				emitter.events.on(PING, function(_) {});
			}
			emitter.events.on(PING, throwsPlainValue);
			var caught:Dynamic = null;
			var stack = "";
			try {
				emitter.events.dispatch(new Event(PING));
			} catch (e:Dynamic) {
				caught = e;
				stack = CallStack.toString(CallStack.exceptionStack());
			}
			Assert.equals("plain", caught);
			#if (cpp && !HXCPP_STACK_TRACE)
			Assert.pass("no stacks natively without HXCPP_STACK_TRACE");
			#elseif (neko || eval)
			Assert.pass("no function names in the stack here");
			#else
			Assert.stringContains("throwsPlainValue", stack);
			#end
		}
	}

	function testARethrownExceptionKeepsTheStackItWasThrownFrom() {
		var emitter = new Emitter();
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PING, throwsException);
		var stack = "";
		try {
			emitter.events.dispatch(new Event(PING));
		} catch (e:haxe.Exception) {
			stack = CallStack.toString(e.stack) + CallStack.toString(CallStack.exceptionStack());
		}
		#if (cpp && !HXCPP_STACK_TRACE)
		Assert.pass("no stacks natively without HXCPP_STACK_TRACE");
		#elseif neko
		Assert.pass("no function names in the stack here");
		#else
		Assert.stringContains("throwsException", stack);
		#end
	}

	function throwsPlainValue(_:Event):Void {
		throw "plain";
	}

	function throwsException(_:Event):Void {
		throw new haxe.Exception("from the listener");
	}

	function testDispatchLocalRunsOnlyThisEmittersListeners() {
		var leaf = new Node("leaf");
		var root = new Node("root");
		leaf.parent = root;
		var log = [];
		leaf.events.on(PING, function(e:Event) log.push("leaf:" + (e.currentTarget == leaf) + "," + (e.target == null)));
		root.events.on(PING, function(_) log.push("root"));
		var event = new Event(PING, true);
		Assert.isTrue(leaf.dispatchLocal(event));
		Assert.equals("leaf:true,true", log.join(","));
		Assert.isNull(event.target);
		Assert.equals(0, leaf.parentReads);
		Assert.isFalse(root.dispatchLocal(new Event("other")));
		Assert.isFalse(root.dispatchLocal(null));
	}

	function testDispatchLocalLeavesAGivenTargetAlone() {
		var a = new Emitter();
		var b = new Emitter();
		var seen:Null<IEmitter> = null;
		b.events.on(PING, function(e:Event) seen = e.target);
		var event = new Event(PING);
		@:privateAccess event.target = a;
		b.dispatchLocal(event);
		Assert.equals((a : IEmitter), seen);
		Assert.equals((b : IEmitter), event.currentTarget);
	}

	function testDispatchContainedRunsEveryListenerAndReportsEachFailure() {
		var emitter = new Recording();
		var log = [];
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.on(PING, function(_) throw new haxe.Exception("b"));
		emitter.events.on(PING, function(_) log.push("c"));
		emitter.events.on(PING, function(_) throw "d");
		emitter.events.on(PING, function(_) log.push("e"));
		Assert.isTrue(emitter.dispatchContained(new Event(PING)));
		Assert.equals("a,c,e", log.join(","));
		Assert.equals("b@ping,d@ping", emitter.thrown.join(","));
		Assert.equals(0, Inside.eventWalks(emitter));
		Assert.isFalse(emitter.dispatchContained(new Event("none")));
		Assert.isFalse(emitter.dispatchContained(null));
	}

	function testDispatchContainedRunsAOnceOnceAndEveryListenerAfterIt() {
		var emitter = new Recording();
		var log = [];
		var nested = false;
		emitter.events.on(PING, function(_) {
			log.push("a");
			if (!nested) {
				nested = true;
				emitter.dispatchContained(new Event(PING));
			}
		});
		emitter.events.once(PING, function(_) {
			log.push("o");
			throw "o";
		});
		emitter.events.on(PING, function(_) log.push("b"));
		emitter.events.once(PING, function(_) log.push("p"));
		emitter.events.on(PING, function(_) log.push("c"));
		emitter.dispatchContained(new Event(PING));
		// The nested dispatch spends both once listeners; the outer one
		// passes over them to every listener after each.
		Assert.equals("a,a,o,b,p,c,b,c", log.join(","));
		emitter.dispatchContained(new Event(PING));
		// Spent where they stood, without a nested dispatch.
		emitter.events.once(PING, function(_) log.push("q"), 1);
		emitter.events.on(PING, function(_) log.push("d"), 1);
		emitter.dispatchContained(new Event(PING));
		Assert.equals("a,a,o,b,p,c,b,c,a,b,c,q,d,a,b,c", log.join(","));
		Assert.equals("o@ping", emitter.thrown.join(","));
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testDispatchContainedReportsTheOnlyListenersFailure() {
		var emitter = new Recording();
		emitter.events.on(PING, function(_) throw new haxe.Exception("only"));
		Assert.isTrue(emitter.dispatchContained(new Event(PING)));
		Assert.equals("only@ping", emitter.thrown.join(","));
	}

	function testAFailingListenerThrewHookStillPutsTheCountBack() {
		var emitter = new Recording();
		emitter.throwFromHook = true;
		emitter.events.on(PING, function(_) {});
		emitter.events.on(PING, function(_) throw new haxe.Exception("listener"));
		var caught = "";
		try {
			emitter.dispatchContained(new Event(PING));
		} catch (e:haxe.Exception) {
			caught = e.message;
		}
		Assert.equals("hook", caught);
		Assert.equals(0, Inside.eventWalks(emitter));
	}

	function testDispatchContainedSetsTargetsAndBubbles() {
		var root = new Recording();
		var log = [];
		var tree = new ContainedTree(root);
		tree.events.on(PING, function(e:Event) {
			log.push("leaf:" + (e.target == tree));
			throw "leaf";
		});
		root.events.on(PING, function(e:Event) log.push("root:" + (e.target == tree) + "," + (e.currentTarget == root)));
		Assert.isTrue(tree.dispatchContained(new Event(PING, true)));
		Assert.equals("leaf:true,root:true,true", log.join(","));
		Assert.equals(1, tree.thrown.length);
	}

	function testStopFlagsAreReadAfterEachListenerNotBefore() {
		var emitter = new Emitter();
		var log = [];
		emitter.events.on(PING, function(_) log.push("a"));
		emitter.events.on(PING, function(e:Event) {
			log.push("b");
			e.stopImmediatePropagation();
		});
		emitter.events.on(PING, function(_) log.push("c"));
		emitter.events.dispatch(new Event(PING));
		Assert.equals("a,b", log.join(","));
	}
}

/** A contained dispatch's leaf, under a recording root. **/
private class ContainedTree extends Recording {
	var root:Emitter;

	public function new(root:Emitter) {
		super();
		this.root = root;
	}

	override public function getEventParent():Null<Emitter> {
		return root;
	}
}
