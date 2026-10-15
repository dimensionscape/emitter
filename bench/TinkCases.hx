package;

import Bench.INNER;
import tink.core.Noise;
import tink.core.Signal;

/**
	tink_core's signals, from its haxelib: one `SignalTrigger` per signal,
	so a class with the signals the other cases use holds four (`Holder`).
	A signal carries one value: no signal of three arguments (its third
	trigger carries an object), and one of none carries `Noise`, which the
	listener takes as it is rather than through tink's wrapping of a
	listener of no arguments. Listened to and fired through the trigger
	itself (`listen`, `trigger`), the fastest of its ways (`handle`, on the
	`Signal` a class shows, calls `listen` through an interface); `listen`
	answers with a link whose `cancel` removes the listener, the only way
	to remove one. Its once is `nextTime`, a future of the next value.
**/
class TinkCases {
	/** A class's four signals, a listener on each. **/
	static function signals():Holder {
		var holder = new Holder();
		holder.s0.listen(function(_:Noise) Bench.sink++);
		holder.s1.listen(function(a:Int) Bench.sink += a);
		holder.s3.listen(function(a:Three) Bench.sink += a.a + a.c);
		holder.sf.listen(function(a:Float) if (a > 1) Bench.sink++);
		return holder;
	}

	static function main() {
		Bench.time("emit, 0 arguments", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s0.trigger(Noise);
				}
			}
		});
		Bench.time("emit, 1 argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.trigger(1);
				}
			}
		});
		Bench.time("emit, 1 Float argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].sf.trigger(0.5);
				}
			}
		});
		Bench.time("emit, 1 argument, 4 listeners", function() {
			var both = [new Holder(), new Holder()];
			for (holder in both) {
				for (_ in 0...4) {
					holder.s1.listen(function(a:Int) Bench.sink += a);
				}
			}
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.trigger(1);
				}
			}
		});
		Bench.time("emit, no listener for the signal", function() {
			var both = [new Holder(), new Holder()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.trigger(1);
				}
			}
		});
		Bench.time("subscribe + cancel, the signal has one", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.listen(listener).cancel();
				}
			}
		});
		Bench.time("once, then emit", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var trigger = both[i & 1].s1;
					trigger.asSignal().nextTime().handle(listener);
					trigger.trigger(1);
				}
			}
		});

		Bench.bytes("idle emitter", function() {
			return function() Bench.kept = new Holder();
		});
		Bench.bytes("emitter with one signal listener", function() {
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				var holder = new Holder();
				holder.s1.listen(listener);
				Bench.kept = holder;
			}
		});
		Bench.bytes("subscribe + cancel, the signal has one", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.listen(listener).cancel();
			}
		});
		Bench.bytes("once, then emit", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.asSignal().nextTime().handle(listener);
				holder.s1.trigger(1);
			}
		});
		Bench.bytes("emit, 1 argument", function() {
			var holder = signals();
			return function() holder.s1.trigger(1);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var holder = signals();
			return function() holder.sf.trigger(0.5);
		});
	}
}

/** What a class with the four signals of the other cases holds. **/
private class Holder {
	public final s0:SignalTrigger<Noise>;
	public final s1:SignalTrigger<Int>;
	public final s3:SignalTrigger<Three>;
	public final sf:SignalTrigger<Float>;

	public function new() {
		s0 = Signal.trigger();
		s1 = Signal.trigger();
		s3 = Signal.trigger();
		sf = Signal.trigger();
	}
}

/** What a signal of three arguments would carry, as one value. **/
private class Three {
	public var a:Int;
	public var b:Dynamic;
	public var c:Int;

	public function new(a:Int, b:Dynamic, c:Int) {
		this.a = a;
		this.b = b;
		this.c = c;
	}
}
