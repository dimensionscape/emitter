package;

import Bench.INNER;
import signals.Signal;
import signals.Signal1;
import signals.Signal3;

/**
	The `signals` haxelib (its `signals` package; `signal` is deprecated):
	one `Signal` per signal, so a class with the signals the other cases use
	holds four (`Holder`). `add` answers with the signal, for chaining, so a
	listener is removed by its function (`remove`) and there is no
	"subscribe + cancel"; once is `add(listener).repeat(0)`, as its README
	has it. On the jvm `remove` with a function throws (it compares its
	argument with `true`, which casts the function to a Boolean), so there
	"on + off" is left out.
**/
class SignalsCases {
	/** A class's four signals, a listener on each. **/
	static function listened():Holder {
		var holder = new Holder();
		holder.s0.add(function() Bench.sink++);
		holder.s1.add(function(a:Int) Bench.sink += a);
		holder.s3.add(function(a:Int, b:Thing, c:Int) Bench.sink += a + c);
		holder.sf.add(function(a:Float) if (a > 1) Bench.sink++);
		return holder;
	}

	static function main() {
		Bench.time("emit, 0 arguments", function() {
			var both = [listened(), listened()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s0.dispatch();
				}
			}
		});
		Bench.time("emit, 1 argument", function() {
			var both = [listened(), listened()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.dispatch(1);
				}
			}
		});
		Bench.time("emit, 3 arguments", function() {
			var both = [listened(), listened()];
			var thing = new Thing();
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s3.dispatch(1, thing, 2);
				}
			}
		});
		Bench.time("emit, 1 Float argument", function() {
			var both = [listened(), listened()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].sf.dispatch(0.5);
				}
			}
		});
		Bench.time("emit, 1 argument, 4 listeners", function() {
			var both = [new Holder(), new Holder()];
			for (holder in both) {
				for (_ in 0...4) {
					holder.s1.add(function(a:Int) Bench.sink += a);
				}
			}
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.dispatch(1);
				}
			}
		});
		Bench.time("emit, no listener for the signal", function() {
			var both = [new Holder(), new Holder()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.dispatch(1);
				}
			}
		});
		#if !jvm
		Bench.time("on + off, the signal has one", function() {
			var both = [listened(), listened()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.add(listener);
					signal.remove(listener);
				}
			}
		});
		#end
		Bench.time("once, then emit", function() {
			var both = [listened(), listened()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.add(listener).repeat(0);
					signal.dispatch(1);
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
				holder.s1.add(listener);
				Bench.kept = holder;
			}
		});
		Bench.bytes("emitter with four signal listeners", function() {
			var l0 = function() Bench.sink++;
			var l1 = function(a:Int) Bench.sink += a;
			var l3 = function(a:Int, b:Thing, c:Int) Bench.sink += a + c;
			var lf = function(a:Float) if (a > 1) Bench.sink++;
			return function() {
				var holder = new Holder();
				holder.s0.add(l0);
				holder.s1.add(l1);
				holder.s3.add(l3);
				holder.sf.add(lf);
				Bench.kept = holder;
			}
		});
		#if !jvm
		Bench.bytes("on + off, the signal has one", function() {
			var holder = listened();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.add(listener);
				holder.s1.remove(listener);
			}
		});
		#end
		Bench.bytes("once, then emit", function() {
			var holder = listened();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.add(listener).repeat(0);
				holder.s1.dispatch(1);
			}
		});
		Bench.bytes("emit, 1 argument", function() {
			var holder = listened();
			return function() holder.s1.dispatch(1);
		});
		Bench.bytes("emit, 3 arguments", function() {
			var holder = listened();
			var thing = new Thing();
			return function() holder.s3.dispatch(1, thing, 2);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var holder = listened();
			return function() holder.sf.dispatch(0.5);
		});
	}
}

/** What a class with the four signals of the other cases holds. **/
private class Holder {
	public final s0:Signal;
	public final s1:Signal1<Int>;
	public final s3:Signal3<Int, Thing, Int>;
	public final sf:Signal1<Float>;

	public function new() {
		s0 = new Signal();
		s1 = new Signal1<Int>();
		s3 = new Signal3<Int, Thing, Int>();
		sf = new Signal1<Float>();
	}
}

private class Thing {
	public function new() {}
}
