package;

import Bench.INNER;
import gx.events.Event;
import gx.events.EventEmitter;
import gx.events.EventType;
import gx.events.Signal0;
import gx.events.Signal1;
import gx.events.Signal3;

/**
	Graphaxe's EventEmitter, built from Graphaxe's own source: every case
	but "duplicates kept" (it always ignores a duplicate). A reused event is
	made ready again by its own `reset`, as Graphaxe's Stage and pointer
	processor do.
**/
@:access(gx.events.Event)
class GraphaxeCases {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";
	static inline var S0:Signal0 = "s0";
	static inline var S1:Signal1<Int> = "s1";
	static inline var S3:Signal3<Int, Event, Int> = "s3";
	static inline var SF:Signal1<Float> = "sf";
	static inline var SN:Signal1<Int> = "sn";

	static function listening(type:EventType<Event>, count:Int):EventEmitter {
		var emitter = new EventEmitter();
		for (_ in 0...count) {
			emitter.addEventListener(type, function(_:Event) Bench.sink++);
		}
		return emitter;
	}

	/** Listening for four types alike in length and in their first and last characters, none of them `PING`. **/
	static function many():EventEmitter {
		var emitter = new EventEmitter();
		for (type in ["pang", "peng", "pung", "pyng"]) {
			emitter.addEventListener(type, function(_:Event) Bench.sink++);
		}
		return emitter;
	}

	static function signals():EventEmitter {
		var emitter = new EventEmitter();
		emitter.on(S0, function() Bench.sink++);
		emitter.on(S1, function(a:Int) Bench.sink += a);
		emitter.on(S3, function(a:Int, b:Event, c:Int) Bench.sink += a + c);
		emitter.on(SF, function(a:Float) if (a > 1) Bench.sink++);
		return emitter;
	}

	static function tree():EventEmitter {
		var root = new Node(null);
		var mid = new Node(root);
		var leaf = new Node(mid);
		for (node in [root, mid, leaf]) {
			node.addEventListener(PING, function(_:Event) Bench.sink++);
		}
		return leaf;
	}

	static function main() {
		Bench.time("dispatch, 1 listener", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reset(PING);
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("dispatch, 1 listener, the event as it was", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("dispatch, 4 listeners", function() {
			var both = [listening(PING, 4), listening(PING, 4)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reset(PING);
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("dispatch, no listener for the type", function() {
			var both = [listening(PONG, 1), listening(PONG, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reset(PING);
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("dispatch, no listener for the type, 4 types listened", function() {
			var both = [many(), many()];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reset(PING);
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("has, the type has one", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			return function() {
				for (i in 0...INNER) {
					if (both[i & 1].hasEventListener(PING)) {
						Bench.sink++;
					}
				}
			}
		});
		Bench.time("add + remove, the type has one", function() {
			var shared = listening(PING, 1);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (_ in 0...INNER) {
					shared.addEventListener(PING, listener);
					shared.removeEventListener(PING, listener);
				}
			}
		});
		Bench.time("subscribe + cancel, the type has one", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (i in 0...INNER) {
					var emitter = both[i & 1];
					emitter.addEventListener(PING, listener);
					emitter.removeEventListener(PING, listener);
				}
			}
		});
		Bench.time("add + remove, the first of its type", function() {
			var other = listening(PONG, 1);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (_ in 0...INNER) {
					other.addEventListener(PING, listener);
					other.removeEventListener(PING, listener);
				}
			}
		});
		Bench.time("emit, 0 arguments", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(S0);
				}
			}
		});
		Bench.time("emit, 1 argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(S1, 1);
				}
			}
		});
		Bench.time("emit, 3 arguments", function() {
			var both = [signals(), signals()];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(S3, 1, event, 2);
				}
			}
		});
		Bench.time("emit, 1 Float argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(SF, 0.5);
				}
			}
		});
		Bench.time("emit, 1 argument, 4 listeners", function() {
			var both = [new EventEmitter(), new EventEmitter()];
			for (emitter in both) {
				for (_ in 0...4) {
					emitter.on(S1, function(a:Int) Bench.sink += a);
				}
			}
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(S1, 1);
				}
			}
		});
		Bench.time("emit, no listener for the signal", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(SN, 1);
				}
			}
		});
		for (name in ["on + off, the signal has one", "subscribe + cancel, the signal has one"]) {
			Bench.time(name, function() {
				var both = [signals(), signals()];
				var listener = function(a:Int) Bench.sink += a;
				return function() {
					for (i in 0...INNER) {
						var emitter = both[i & 1];
						emitter.on(S1, listener);
						emitter.off(S1, listener);
					}
				}
			});
		}
		Bench.time("once, then emit", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var emitter = both[i & 1];
					emitter.once(S1, listener);
					emitter.emit(S1, 1);
				}
			}
		});
		Bench.time("bubble, 3 levels, a listener on each", function() {
			var both = [tree(), tree()];
			var event = new Event(PING, true);
			return function() {
				for (i in 0...INNER) {
					event.reset(PING, true);
					both[i & 1].dispatchEvent(event);
				}
			}
		});

		Bench.bytes("idle emitter", function() {
			return function() Bench.kept = new EventEmitter();
		});
		Bench.bytes("emitter with one listener", function() {
			var listener = function(_:Event) Bench.sink++;
			return function() {
				var made = new EventEmitter();
				made.addEventListener(PING, listener);
				Bench.kept = made;
			}
		});
		Bench.bytes("dispatch, 1 listener", function() {
			var one = listening(PING, 1);
			var event = new Event(PING);
			return function() {
				event.reset(PING);
				one.dispatchEvent(event);
			}
		});
		Bench.bytes("dispatch, 4 listeners", function() {
			var four = listening(PING, 4);
			var event = new Event(PING);
			return function() {
				event.reset(PING);
				four.dispatchEvent(event);
			}
		});
		Bench.bytes("emit, 1 argument", function() {
			var emitter = signals();
			return function() emitter.emit(S1, 1);
		});
		Bench.bytes("emit, 3 arguments", function() {
			var emitter = signals();
			var event = new Event(PING);
			return function() emitter.emit(S3, 1, event, 2);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var emitter = signals();
			return function() emitter.emit(SF, 0.5);
		});
		Bench.bytes("bubble, 3 levels, a listener on each", function() {
			var leaf = tree();
			var event = new Event(PING, true);
			return function() {
				event.reset(PING, true);
				leaf.dispatchEvent(event);
			}
		});
		Bench.bytes("add + remove, the type has one", function() {
			var shared = listening(PING, 1);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				shared.addEventListener(PING, listener);
				shared.removeEventListener(PING, listener);
			}
		});
	}
}

private class Node extends EventEmitter {
	var parent:Null<Node>;

	public function new(parent:Null<Node>) {
		super();
		this.parent = parent;
	}

	override public function getEventParent():EventEmitter {
		return parent;
	}
}
