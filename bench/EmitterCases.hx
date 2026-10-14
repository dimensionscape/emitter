package;

import Bench.INNER;
import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal0;
import emitter.Signal1;
import emitter.Signal3;

/**
	Emitter 2.0's cases. Each has a twin of the same name in the other
	dispatchers' mains, and builds what it measures itself.
**/
class EmitterCases {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";
	static inline var S0:Signal0 = "s0";
	static inline var S1:Signal1<Int> = "s1";
	static inline var S3:Signal3<Int, Event, Int> = "s3";
	static inline var SF:Signal1<Float> = "sf";
	static inline var SN:Signal1<Int> = "sn";

	static function listening(type:EventType<Event>, count:Int):Emitter {
		var emitter = new Emitter();
		for (_ in 0...count) {
			emitter.on(type, function(_:Event) Bench.sink++);
		}
		return emitter;
	}

	/** Listening for four types alike in length and in their first and last characters, none of them `PING`. **/
	static function many():Emitter {
		var emitter = new Emitter();
		for (type in ["pang", "peng", "pung", "pyng"]) {
			emitter.on(type, function(_:Event) Bench.sink++);
		}
		return emitter;
	}

	static function signals():Emitter {
		var emitter = new Emitter();
		emitter.on(S0, function() Bench.sink++);
		emitter.on(S1, function(a:Int) Bench.sink += a);
		emitter.on(S3, function(a:Int, b:Event, c:Int) Bench.sink += a + c);
		emitter.on(SF, function(a:Float) if (a > 1) Bench.sink++);
		return emitter;
	}

	static function tree():Emitter {
		var root = new Node(null);
		var mid = new Node(root);
		var leaf = new Node(mid);
		for (node in [root, mid, leaf]) {
			node.on(PING, function(_:Event) Bench.sink++);
		}
		return leaf;
	}

	static function main() {
		Bench.time("dispatch, 1 listener", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reuse();
					both[i & 1].dispatch(event);
				}
			}
		});
		Bench.time("dispatch, 1 listener, the event as it was", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					both[i & 1].dispatch(event);
				}
			}
		});
		Bench.time("dispatch, 4 listeners", function() {
			var both = [listening(PING, 4), listening(PING, 4)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reuse();
					both[i & 1].dispatch(event);
				}
			}
		});
		Bench.time("dispatch, no listener for the type", function() {
			var both = [listening(PONG, 1), listening(PONG, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reuse();
					both[i & 1].dispatch(event);
				}
			}
		});
		Bench.time("dispatch, no listener for the type, 4 types listened", function() {
			var both = [many(), many()];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.reuse();
					both[i & 1].dispatch(event);
				}
			}
		});
		Bench.time("has, the type has one", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			return function() {
				for (i in 0...INNER) {
					if (both[i & 1].has(PING)) {
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
					shared.on(PING, listener);
					shared.off(PING, listener);
				}
			}
		});
		Bench.time("add + remove, the type has one, duplicates kept", function() {
			var keeping = new Emitter();
			keeping.allowDuplicates = true;
			keeping.on(PING, function(_:Event) Bench.sink++);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (_ in 0...INNER) {
					keeping.on(PING, listener);
					keeping.off(PING, listener);
				}
			}
		});
		Bench.time("subscribe + cancel, the type has one", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (i in 0...INNER) {
					both[i & 1].on(PING, listener).cancel();
				}
			}
		});
		Bench.time("add + remove, the first of its type", function() {
			var other = listening(PONG, 1);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				for (_ in 0...INNER) {
					other.on(PING, listener);
					other.off(PING, listener);
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
			var both = [new Emitter(), new Emitter()];
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
		Bench.time("on + off, the signal has one", function() {
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
		Bench.time("subscribe + cancel, the signal has one", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					both[i & 1].on(S1, listener).cancel();
				}
			}
		});
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
					event.reuse();
					both[i & 1].dispatch(event);
				}
			}
		});

		Bench.bytes("emitter with one signal listener", function() {
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				var emitter = new Emitter();
				emitter.on(S1, listener);
				Bench.kept = emitter;
			}
		});
		Bench.bytes("on + off, the signal has one", function() {
			var emitter = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				emitter.on(S1, listener);
				emitter.off(S1, listener);
			}
		});
		Bench.bytes("subscribe + cancel, the signal has one", function() {
			var emitter = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				emitter.on(S1, listener).cancel();
			}
		});
		Bench.bytes("once, then emit", function() {
			var emitter = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				emitter.once(S1, listener);
				emitter.emit(S1, 1);
			}
		});
		Bench.bytes("idle emitter", function() {
			return function() Bench.kept = new Emitter();
		});
		Bench.bytes("emitter with one listener", function() {
			var listener = function(_:Event) Bench.sink++;
			return function() {
				var made = new Emitter();
				made.on(PING, listener);
				Bench.kept = made;
			}
		});
		Bench.bytes("dispatch, 1 listener", function() {
			var one = listening(PING, 1);
			var event = new Event(PING);
			return function() {
				event.reuse();
				one.dispatch(event);
			}
		});
		Bench.bytes("dispatch, 4 listeners", function() {
			var four = listening(PING, 4);
			var event = new Event(PING);
			return function() {
				event.reuse();
				four.dispatch(event);
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
				event.reuse();
				leaf.dispatch(event);
			}
		});
		Bench.bytes("add + remove, the type has one", function() {
			var shared = listening(PING, 1);
			var listener = function(_:Event) Bench.sink++;
			return function() {
				shared.on(PING, listener);
				shared.off(PING, listener);
			}
		});
	}
}

private class Node extends Emitter {
	var parent:Null<Node>;

	public function new(parent:Null<Node>) {
		super();
		this.parent = parent;
	}

	override public function getEventParent():Null<Emitter> {
		return parent;
	}
}
