package;

import Bench.INNER;
import hxsignal.Signal;

/**
	hxsignal, from its haxelib: one `Signal` per signal, typed by its
	listener, so a class with the signals the other cases use holds four
	(`Holder`). `connect` answers nothing, so a listener is removed by its
	function (`disconnect`) and there is no "subscribe + cancel"; once is
	`connect(listener, Once)`.
**/
class HxSignalCases {
	/** A class's four signals, a listener on each. **/
	static function signals():Holder {
		var holder = new Holder();
		holder.s0.connect(function() Bench.sink++);
		holder.s1.connect(function(a:Int) Bench.sink += a);
		holder.s3.connect(function(a:Int, b:Thing, c:Int) Bench.sink += a + c);
		holder.sf.connect(function(a:Float) if (a > 1) Bench.sink++);
		return holder;
	}

	static function main() {
		Bench.time("emit, 0 arguments", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s0.emit();
				}
			}
		});
		Bench.time("emit, 1 argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.emit(1);
				}
			}
		});
		Bench.time("emit, 3 arguments", function() {
			var both = [signals(), signals()];
			var thing = new Thing();
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s3.emit(1, thing, 2);
				}
			}
		});
		Bench.time("emit, 1 Float argument", function() {
			var both = [signals(), signals()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].sf.emit(0.5);
				}
			}
		});
		Bench.time("emit, 1 argument, 4 listeners", function() {
			var both = [new Holder(), new Holder()];
			for (holder in both) {
				for (_ in 0...4) {
					holder.s1.connect(function(a:Int) Bench.sink += a);
				}
			}
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.emit(1);
				}
			}
		});
		Bench.time("emit, no listener for the signal", function() {
			var both = [new Holder(), new Holder()];
			return function() {
				for (i in 0...INNER) {
					both[i & 1].s1.emit(1);
				}
			}
		});
		Bench.time("on + off, the signal has one", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.connect(listener);
					signal.disconnect(listener);
				}
			}
		});
		Bench.time("once, then emit", function() {
			var both = [signals(), signals()];
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				for (i in 0...INNER) {
					var signal = both[i & 1].s1;
					signal.connect(listener, Once);
					signal.emit(1);
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
				holder.s1.connect(listener);
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
				holder.s0.connect(l0);
				holder.s1.connect(l1);
				holder.s3.connect(l3);
				holder.sf.connect(lf);
				Bench.kept = holder;
			}
		});
		Bench.bytes("on + off, the signal has one", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.connect(listener);
				holder.s1.disconnect(listener);
			}
		});
		Bench.bytes("once, then emit", function() {
			var holder = signals();
			var listener = function(a:Int) Bench.sink += a;
			return function() {
				holder.s1.connect(listener, Once);
				holder.s1.emit(1);
			}
		});
		Bench.bytes("emit, 1 argument", function() {
			var holder = signals();
			return function() holder.s1.emit(1);
		});
		Bench.bytes("emit, 3 arguments", function() {
			var holder = signals();
			var thing = new Thing();
			return function() holder.s3.emit(1, thing, 2);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var holder = signals();
			return function() holder.sf.emit(0.5);
		});
	}
}

/** What a class with the four signals of the other cases holds. **/
private class Holder {
	public final s0:Signal<() -> Void>;
	public final s1:Signal<Int->Void>;
	public final s3:Signal<(Int, Thing, Int) -> Void>;
	public final sf:Signal<Float->Void>;

	public function new() {
		s0 = new Signal<() -> Void>();
		s1 = new Signal<Int->Void>();
		s3 = new Signal<(Int, Thing, Int) -> Void>();
		sf = new Signal<Float->Void>();
	}
}

private class Thing {
	public function new() {}
}
