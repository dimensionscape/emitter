package;

import Bench.INNER;
import msignal.Signal;

/**
	msignal, from its haxelib: one `Signal` object per signal, so a class
	with the signals the other cases use holds four of them (`Holder`).
	Its widest signal takes two arguments, so it has no "emit, 3
	arguments"; its third signal is a `Signal2` instead. `add` answers with
	the listener's slot, whose `remove` is the subscription's cancel, and
	`addOnce` listens for the next dispatch only.
**/
class MSignalCases {
	/** A class's four signals, a listener on each. **/
	static function signals():Holder {
		var holder = new Holder();
		holder.s0.add(function() Bench.sink++);
		holder.s1.add(function(a:Int) Bench.sink += a);
		holder.s2.add(function(a:Int, b:Thing) Bench.sink += a);
		holder.sf.add(function(a:Float) if (a > 1) Bench.sink++);
		return holder;
	}

	static function main() {
		Bench.time("emit, 0 arguments", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s0.dispatch();
				}
			}
		});
		Bench.time("emit, 1 argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.dispatch(1);
				}
			}
		});
		Bench.time("emit, 1 Float argument", function() {
			var both = [signals(), signals()];
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
		Bench.time("on + off, the signal has one", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.add(listener);
					signal.remove(listener);
				}
			}
		});
		Bench.time("subscribe + cancel, the signal has one", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.add(listener).remove();
				}
			}
		});
		Bench.time("once, then emit", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.addOnce(listener);
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
		Bench.bytes("on + off, the signal has one", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.add(listener);
				holder.s1.remove(listener);
			}
		});
		Bench.bytes("subscribe + cancel, the signal has one", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.add(listener).remove();
			}
		});
		Bench.bytes("once, then emit", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.addOnce(listener);
				holder.s1.dispatch(1);
			}
		});
		Bench.bytes("emit, 1 argument", function() {
			var holder = signals();
			return function() holder.s1.dispatch(1);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var holder = signals();
			return function() holder.sf.dispatch(0.5);
		});
	}
}

/** What a class with the four signals of the other cases holds. **/
private class Holder {
	public final s0:Signal0;
	public final s1:Signal1<Int>;
	public final s2:Signal2<Int, Thing>;
	public final sf:Signal1<Float>;

	public function new() {
		s0 = new Signal0();
		s1 = new Signal1<Int>();
		s2 = new Signal2<Int, Thing>();
		sf = new Signal1<Float>();
	}
}

private class Thing {
	public function new() {}
}
