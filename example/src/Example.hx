import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal0;
import emitter.Signal2;

/**
	A tour of Emitter: signals, events, removing listeners, bubbling, and a
	framework layer. Run it with `haxe build.hxml` in this folder.
**/
class Example {
	static function main() {
		signals();
		events();
		removing();
		bubbling();
		frameworkLayer();
	}

	static function signals() {
		trace("Signals");
		var player = new Player();
		player.on(Player.MOVED, (x, y) -> trace("moved by " + (x + y)));
		player.emit(Player.MOVED, 1.5, 2.5);

		// A higher priority runs earlier; once listens for the next emit only.
		player.on(Player.TICK, () -> trace("tick"));
		player.on(Player.TICK, () -> trace("first, priority 10"), 10);
		player.once(Player.TICK, () -> trace("only the first time"));
		player.emit(Player.TICK);
		player.emit(Player.TICK);
		trace("heard by anyone: " + player.emit(Player.NOTHING));
	}

	static function events() {
		trace("Events");
		var game = new Emitter();
		game.on(ScoreEvent.SCORED, event -> trace("scored " + event.points));
		game.dispatch(new ScoreEvent(10));

		// Adding an event listener already there does nothing.
		var onScored = (event:ScoreEvent) -> trace("added twice, heard once");
		game.on(ScoreEvent.SCORED, onScored);
		game.on(ScoreEvent.SCORED, onScored);
		game.dispatch(new ScoreEvent(20));
	}

	static function removing() {
		trace("Removing");
		var player = new Player();

		// A subscription removes its listener, a lambda included.
		var moved = player.on(Player.MOVED, (x, y) -> trace("never heard"));
		moved.cancel();
		trace("still listening: " + moved.active);

		// off removes a method by reading it again.
		var hud = new Hud(player);
		player.emit(Player.MOVED, 1, 2);
		hud.close(player);
		trace("anything listening: " + player.has(Player.MOVED));

		// clear removes every listener of a signal, or with nothing given, all.
		player.on(Player.TICK, () -> {});
		player.clear();
		trace("anything listening after clear: " + player.has(Player.TICK));
	}

	static function bubbling() {
		trace("Bubbling");
		var root = new Node();
		var leaf = new Node(root);
		var rootHeard = false;
		root.on(Event.CHANGE, event -> {
			rootHeard = true;
			trace("root heard it, dispatched on the leaf: " + (event.target == leaf));
		});
		leaf.dispatch(new Event(Event.CHANGE, true));

		// A listener on the way can stop it.
		rootHeard = false;
		leaf.on(Event.CHANGE, event -> event.stopPropagation());
		leaf.dispatch(new Event(Event.CHANGE, true));
		trace("root heard it after the leaf stopped it: " + rootHeard);
	}

	static function frameworkLayer() {
		trace("A framework layer");
		var sprite = new Sprite();
		var onFrame = (event:Event) -> {};
		sprite.addEventListener(Sprite.ENTER_FRAME, onFrame);
		trace("listening for frames: " + sprite.hasEventListener("enterFrame"));
		sprite.removeEventListener(Sprite.ENTER_FRAME, onFrame);
	}
}

class Player extends Emitter {
	public static inline var MOVED:Signal2<Float, Float> = "moved";
	public static inline var TICK:Signal0 = "tick";
	public static inline var NOTHING:Signal0 = "nothing";

	public function new() {
		super();
	}
}

class Hud {
	public function new(player:Player) {
		player.on(Player.MOVED, onMoved);
	}

	public function close(player:Player) {
		player.off(Player.MOVED, onMoved);
	}

	function onMoved(x:Float, y:Float):Void {
		trace("hud saw a move to " + x + ", " + y);
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

/**
	A framework's dispatcher: ActionScript's names as one-line inline
	methods, and a registry kept from `listenersChanged`.
**/
class EventDispatcher extends Emitter {
	public function new() {
		super();
	}

	public inline function addEventListener<T:Event>(type:EventType<T>, listener:T->Void, priority:Int = 0):Void {
		on(type, listener, priority);
	}

	public inline function removeEventListener<T:Event>(type:EventType<T>, listener:T->Void):Void {
		off(type, listener);
	}

	public inline function hasEventListener(type:String):Bool {
		return has(type);
	}

	public inline function dispatchEvent(event:Event):Bool {
		return dispatch(event);
	}
}

/** A display object that registers for frames when something listens for them. **/
class Sprite extends EventDispatcher {
	public static inline var ENTER_FRAME:EventType<Event> = "enterFrame";

	override private function listenersChanged(type:String, present:Bool):Void {
		if (type == ENTER_FRAME) {
			trace(present ? "registered for frames" : "dropped from frames");
		}
	}
}
