package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.IEmitter;
import support.Support;
import utest.Assert;
import utest.Test;

/**
	What Graphaxe's display tree relies on, each in the shape Graphaxe uses
	it (events\graphaxe-events.md, "Must keep"): a change that breaks one of
	these breaks Graphaxe.
**/
class GraphaxeReliesOnTest extends Test {
	static inline var TRIGGERED:EventType<Event> = "triggered";
	static inline var ENTER_FRAME:EventType<Event> = "enterFrame";
	static inline var RENDER:EventType<Event> = "render";
	static inline var POINTER_UP:EventType<Event> = "pointerUp";

	function testAPooledRendererReAddedOnEveryReuseFiresOnce() {
		// ui/List.hx adds TRIGGERED to a pooled renderer each time it is
		// reused, and removes it only on dispose.
		var renderer = new Shape("renderer");
		var triggered = 0;
		var list = new ListLike(function(_) triggered++);
		for (_ in 0...5) {
			list.reuse(renderer);
		}
		renderer.events.dispatch(new Event(TRIGGERED));
		Assert.equals(1, triggered);
		list.dispose(renderer);
		renderer.events.dispatch(new Event(TRIGGERED));
		Assert.equals(1, triggered);
	}

	function testAListenerAddedToTheStageWhileAnEventBubblesRunsForIt() {
		// ui/DropDown.hx: a pointer-up on the button opens the list and adds a
		// stage listener for the same pointer-up, which then reaches the
		// stage and must be told to ignore that release.
		var stage = new Shape("stage");
		var dropDown = new Shape("dropDown", stage);
		var button = new Shape("button", dropDown);
		var log = [];
		var ignoreNextStageRelease = false;
		var onStageRelease:Event->Void = null;
		onStageRelease = function(_:Event) {
			if (ignoreNextStageRelease) {
				ignoreNextStageRelease = false;
				log.push("ignored");
				return;
			}
			log.push("closed");
			stage.events.off(POINTER_UP, onStageRelease);
		};
		button.events.on(POINTER_UP, function(_) {
			log.push("opened");
			ignoreNextStageRelease = true;
			stage.events.on(POINTER_UP, onStageRelease);
		});
		button.events.dispatch(new Event(POINTER_UP, true));
		Assert.equals("opened,ignored", log.join(","));
		stage.events.dispatch(new Event(POINTER_UP, true));
		Assert.equals("opened,ignored,closed", log.join(","));
		Assert.isFalse(stage.events.has(POINTER_UP));
	}

	function testAListenerRemovingAndAddingItselfDuringADispatchIsSafe() {
		var shape = new Shape("canvas");
		var log = [];
		var rearm:Event->Void = null;
		rearm = function(_:Event) {
			log.push("rearm");
			shape.events.off(ENTER_FRAME, rearm);
			shape.events.on(ENTER_FRAME, rearm);
		};
		var once:Event->Void = null;
		once = function(_:Event) {
			log.push("once");
			shape.events.off(ENTER_FRAME, once);
		};
		shape.events.on(ENTER_FRAME, rearm);
		shape.events.on(ENTER_FRAME, once);
		shape.events.on(ENTER_FRAME, function(_) log.push("last"));
		shape.events.dispatch(new Event(ENTER_FRAME));
		shape.events.dispatch(new Event(ENTER_FRAME));
		Assert.equals("rearm,once,last,last,rearm", log.join(","));
	}

	function testHasEventListenerGatesInputExactlyDuringADispatch() {
		// events/PointerProcessor.hx walks the chain asking each node whether
		// it listens, per pointer per frame, while listeners come and go.
		var stage = new Shape("stage");
		var button = new Shape("button", stage);
		var answers = [];
		var press = function(_:Event) {};
		button.events.on(POINTER_UP, function(_) {
			button.events.off(POINTER_UP, press);
			answers.push(button.events.has(POINTER_UP, press));
			answers.push(stage.events.has(POINTER_UP));
			stage.events.on(POINTER_UP, press);
			answers.push(stage.events.has(POINTER_UP));
		});
		button.events.on(POINTER_UP, press);
		button.events.dispatch(new Event(POINTER_UP));
		Assert.equals("false,false,true", answers.join(","));
	}

	function testTheStageRegistryFollowsEveryPathThatAddsOrRemoves() {
		// display/DisplayObject.hx registers an object for ENTER_FRAME and
		// RENDER on its first listener and drops it on its last: from the
		// hook, so a subscription cancelled, once and removing everything keep
		// it right too.
		var stage = new StageLike();
		var shape = new Shape("shape", null, stage);
		var listener = function(_:Event) {};

		var subscription = shape.events.on(ENTER_FRAME, listener, 5);
		Assert.equals("shape", stage.frames());
		subscription.cancel();
		Assert.equals("", stage.frames());

		shape.events.once(ENTER_FRAME, function(_) {});
		Assert.equals("shape", stage.frames());
		stage.frame();
		Assert.equals("", stage.frames());

		shape.events.on(ENTER_FRAME, listener);
		shape.events.on(RENDER, listener);
		Assert.equals("shape", stage.frames());
		Assert.equals("shape", stage.renders());
		shape.events.clear();
		Assert.equals("", stage.frames());
		Assert.equals("", stage.renders());

		shape.events.on(ENTER_FRAME, listener);
		shape.events.on(ENTER_FRAME, function(_) {});
		shape.events.clear();
		Assert.equals("", stage.frames());

		shape.events.on(RENDER, listener);
		shape.events.clear(RENDER);
		Assert.equals("", stage.renders());
	}

	function testFirstInFirstOutWithStopImmediatePropagation() {
		// RichTextField and the text overlays rely on running first and
		// stopping the rest.
		var field = new Shape("field");
		var log = [];
		field.events.on(POINTER_UP, function(e:Event) {
			log.push("overlay");
			e.stopImmediatePropagation();
		});
		field.events.on(POINTER_UP, function(_) log.push("field"));
		field.events.dispatch(new Event(POINTER_UP));
		Assert.equals("overlay", log.join(","));
	}

	function testAPrebuiltChainRunsEachNodeOnceThroughDispatchLocal() {
		// PointerEvent.dispatch walks a chain built once per frame, marking
		// each dispatcher so it runs at most once per pass.
		var stage = new Shape("stage");
		var panel = new Shape("panel", stage);
		var button = new Shape("button", panel);
		var log = [];
		for (node in [stage, panel, button]) {
			var name = node.name;
			node.events.on(POINTER_UP, function(e:Event) log.push(name + ">" + Std.string(e.currentTarget)));
		}
		var chain = [button, panel, panel, stage];
		var event = new Event(POINTER_UP, true);
		@:privateAccess event.target = button;
		var mark = 7;
		for (node in chain) {
			if (node.inputMark == mark) {
				continue;
			}
			node.inputMark = mark;
			node.dispatchLocal(event);
			if (event.propagationStopped) {
				break;
			}
		}
		Assert.equals("button>button,panel>panel,stage>stage", log.join(","));
		Assert.equals(0, button.parentReads + panel.parentReads + stage.parentReads);
	}

	function testAWindowMadeWithoutItsConstructorListens() {
		// runtime/Window.hx is made by Type.createEmptyInstance.
		var window:BareNode = Type.createEmptyInstance(BareNode);
		var heard = 0;
		window.events.on(Event.CLOSE, function(_) heard++);
		window.events.dispatch(new Event(Event.CLOSE));
		Assert.equals(1, heard);
	}

	function testOneFrameEventReusedAcrossObjectsSaysTheRightTarget() {
		// The Stage keeps one ENTER_FRAME event and dispatches it to each
		// registered object; reuse() before each makes each one its target
		// and keeps one object's stop from reaching the next.
		var a = new Shape("a");
		var b = new Shape("b");
		var targets = [];
		a.events.on(ENTER_FRAME, function(e:Event) {
			targets.push(Std.string(e.target));
			e.stopImmediatePropagation();
		});
		b.events.on(ENTER_FRAME, function(e:Event) targets.push(Std.string(e.target)));
		b.events.on(ENTER_FRAME, function(e:Event) targets.push("b2"));
		var frame = new Event(ENTER_FRAME);
		for (shape in [a, b]) {
			frame.reuse();
			shape.events.dispatch(frame);
		}
		Assert.equals("a,b,b2", targets.join(","));
	}

	function testDispatchSaysWhetherAnyNodeListened() {
		var stage = new Shape("stage");
		var button = new Shape("button", stage);
		Assert.isFalse(button.events.dispatch(new Event(TRIGGERED, true)));
		stage.events.on(TRIGGERED, function(_) {});
		Assert.isTrue(button.events.dispatch(new Event(TRIGGERED, true)));
	}
}

/** A display object: a node with an input mark and, on a stage, a frame registry. **/
private class Shape extends Node {
	public var inputMark:Int = 0;

	var stage:Null<StageLike>;

	public function new(name:String, ?parent:Shape, ?stage:StageLike) {
		super(name, parent);
		this.stage = stage;
	}

	override private function listenersChanged(type:String, present:Bool):Void {
		if (stage != null) {
			stage.register(this, type, present);
		}
	}
}

/** The stage's registry of objects wanting ENTER_FRAME and RENDER. **/
private class StageLike {
	var enterFrame:Array<Shape> = [];
	var render:Array<Shape> = [];

	public function new() {}

	public function register(shape:Shape, type:String, present:Bool):Void {
		var list = type == "enterFrame" ? enterFrame : (type == "render" ? render : null);
		if (list == null) {
			return;
		}
		if (present) {
			if (list.indexOf(shape) < 0) {
				list.push(shape);
			}
		} else {
			list.remove(shape);
		}
	}

	public function frame():Void {
		var event = new Event("enterFrame");
		for (shape in enterFrame.copy()) {
			event.reuse();
			shape.events.dispatch(event);
		}
	}

	public function frames():String {
		return [for (shape in enterFrame) shape.name].join(",");
	}

	public function renders():String {
		return [for (shape in render) shape.name].join(",");
	}
}

/** ui/List.hx's handling of a pooled item renderer. **/
private class ListLike {
	var onTriggered:Event->Void;

	public function new(onTriggered:Event->Void) {
		this.onTriggered = onTriggered;
	}

	public function reuse(renderer:Emitter):Void {
		renderer.events.on("triggered", onTriggered);
	}

	public function dispose(renderer:Emitter):Void {
		renderer.events.off("triggered", onTriggered);
	}
}
