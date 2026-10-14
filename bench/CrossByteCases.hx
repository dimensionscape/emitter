package;

import Bench.INNER;
import crossbyte.events.Event;
import crossbyte.events.EventDispatcher;
import crossbyte.events.EventType;

/**
	CrossByte's EventDispatcher, built from CrossByte's own source: the
	cases it has (no signals, no bubbling). It keeps duplicates, so both
	add + remove cases are the one operation for it. A reused event is made
	ready again by its own `__retarget`, as CrossByte's arrivals are.
**/
@:access(crossbyte.events.Event)
class CrossByteCases {
	static inline var PING:EventType<Event> = "ping";
	static inline var PONG:EventType<Event> = "pong";

	static function listening(type:EventType<Event>, count:Int):EventDispatcher {
		var dispatcher = new EventDispatcher();
		for (_ in 0...count) {
			dispatcher.addEventListener(type, function(_:Event) Bench.sink++);
		}
		return dispatcher;
	}

	static function main() {
		Bench.time("dispatch, 1 listener", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.__retarget();
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
					event.__retarget();
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("dispatch, no listener for the type", function() {
			var both = [listening(PONG, 1), listening(PONG, 1)];
			var event = new Event(PING);
			return function() {
				for (i in 0...INNER) {
					event.__retarget();
					both[i & 1].dispatchEvent(event);
				}
			}
		});
		Bench.time("hasEventListener", function() {
			var both = [listening(PING, 1), listening(PING, 1)];
			return function() {
				for (i in 0...INNER) {
					if (both[i & 1].hasEventListener(PING)) {
						Bench.sink++;
					}
				}
			}
		});
		for (name in ["add + remove, the type has one", "add + remove, the type has one, duplicates kept"]) {
			Bench.time(name, function() {
				var shared = listening(PING, 1);
				var listener = function(_:Event) Bench.sink++;
				return function() {
					for (_ in 0...INNER) {
						shared.addEventListener(PING, listener);
						shared.removeEventListener(PING, listener);
					}
				}
			});
		}
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

		Bench.bytes("idle emitter", function() {
			return function() Bench.kept = new EventDispatcher();
		});
		Bench.bytes("emitter with one listener", function() {
			var listener = function(_:Event) Bench.sink++;
			return function() {
				var made = new EventDispatcher();
				made.addEventListener(PING, listener);
				Bench.kept = made;
			}
		});
		Bench.bytes("dispatch, 1 listener", function() {
			var one = listening(PING, 1);
			var event = new Event(PING);
			return function() {
				event.__retarget();
				one.dispatchEvent(event);
			}
		});
		Bench.bytes("dispatch, 4 listeners", function() {
			var four = listening(PING, 4);
			var event = new Event(PING);
			return function() {
				event.__retarget();
				four.dispatchEvent(event);
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
