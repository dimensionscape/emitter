import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal0;
import emitter.Signal2;

/**
	A tour of Emitter: events, bubbling, signals, and the hooks a
	framework builds on. Run it with `haxe build.hxml` in this folder.
**/
class Example {
	static function main() {
		events();
		bubbling();
		signals();
		frameworkHooks();
	}

	static function events() {
		trace("Events");
		var game = new Emitter();
		game.addEventListener(ScoreEvent.SCORED, function(event:ScoreEvent) trace("scored " + event.points));

		// Higher priorities run first; once listens for the next event only.
		game.on(ScoreEvent.SCORED, function(event:ScoreEvent) trace("first, priority 10"), 10)
			.once(ScoreEvent.SCORED, function(event:ScoreEvent) trace("only the first time"));
		game.dispatchEvent(new ScoreEvent(10));
		game.dispatchEvent(new ScoreEvent(20));

		// Adding a listener that is already there does nothing.
		game.removeAllListeners();
		var onScored = function(event:ScoreEvent) trace("added twice, heard once");
		game.addEventListener(ScoreEvent.SCORED, onScored);
		game.addEventListener(ScoreEvent.SCORED, onScored);
		game.dispatchEvent(new ScoreEvent(30));
		trace("listening: " + game.has(ScoreEvent.SCORED, onScored));
		game.removeEventListener(ScoreEvent.SCORED, onScored);
		trace("anything listening: " + game.hasEventListener(ScoreEvent.SCORED));
	}

	static function bubbling() {
		trace("Bubbling");
		var root = new Node();
		var leaf = new Node(root);
		var rootHeard = false;
		root.addEventListener(Event.CHANGE, function(event:Event) {
			rootHeard = true;
			trace("root heard it, dispatched on the leaf: " + (event.target == leaf));
		});
		leaf.dispatchEvent(new Event(Event.CHANGE, true));

		// A listener on the way can stop it.
		rootHeard = false;
		leaf.addEventListener(Event.CHANGE, function(event:Event) event.stopPropagation());
		leaf.dispatchEvent(new Event(Event.CHANGE, true));
		trace("root heard it after the leaf stopped it: " + rootHeard);
	}

	static function signals() {
		trace("Signals");
		var player = new Player();
		player.on(Player.MOVED, function(x:Float, y:Float) trace("moved by " + (x + y)));
		player.emit(Player.MOVED, 1.5, 2.5);

		// A signal listener added twice is called twice; each off removes one.
		var count = 0;
		var tick = function() count++;
		player.on(Player.TICK, tick).on(Player.TICK, tick);
		player.emit(Player.TICK);
		trace("ticks heard: " + count);
		player.off(Player.TICK, tick).off(Player.TICK, tick);
		trace("anything listening: " + player.emit(Player.TICK));
	}

	static function frameworkHooks() {
		trace("Hooks");
		var sprite = new Sprite();
		var onFrame = function(event:Event) {};
		sprite.addEventListener(Sprite.ENTER_FRAME, onFrame);
		sprite.removeEventListener(Sprite.ENTER_FRAME, onFrame);
	}
}

class ScoreEvent extends Event {
	public static inline var SCORED:EventType<ScoreEvent> = "scored";

	public var points:Int;

	public function new(points:Int) {
		super(SCORED);
		this.points = points;
	}
}

class Node extends Emitter {
	public var parent:Null<Node>;

	public function new(?parent:Node) {
		super();
		this.parent = parent;
	}

	override public function getEventParent():Null<Emitter> {
		return parent;
	}
}

class Player extends Emitter {
	public static inline var MOVED:Signal2<Float, Float> = "moved";
	public static inline var TICK:Signal0 = "tick";

	public function new() {
		super();
	}
}

/** A display object that registers for frames when something listens for them. **/
class Sprite extends Emitter {
	public static inline var ENTER_FRAME:EventType<Event> = "enterFrame";

	public function new() {
		super();
	}

	override private function listenersChanged(type:String, present:Bool):Void {
		if (type == ENTER_FRAME) {
			trace(present ? "registered for frames" : "dropped from frames");
		}
	}
}
