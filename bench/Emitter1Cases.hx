package;

import Bench.INNER;
import emitter.Emitter;
import emitter.signals.SignalType;

/**
	Emitter 1.0.0, built from its tag in this repository's history: the
	signal cases (it has no events), and its idle size.
**/
class Emitter1Cases {
	static inline var S0:SignalType<Void->Void> = "s0";
	static inline var S1:SignalType1<Int->Void, Int> = "s1";
	static inline var S3:SignalType3<(Int, Thing, Int) -> Void, Int, Thing, Int> = "s3";
	static inline var SF:SignalType1<Float->Void, Float> = "sf";

	static function signals():Emitter {
		var emitter = new Emitter();
		emitter.on(S0, function() Bench.sink++);
		emitter.on(S1, function(a:Int) Bench.sink += a);
		emitter.on(S3, function(a:Int, b:Thing, c:Int) Bench.sink += a + c);
		emitter.on(SF, function(a:Float) if (a > 1) Bench.sink++);
		return emitter;
	}

	static function main() {
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
			var thing = new Thing();
			return function() {
				for (i in 0...INNER) {
					both[i & 1].emit(S3, 1, thing, 2);
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

		Bench.bytes("idle emitter", function() {
			return function() Bench.kept = new Emitter();
		});
		Bench.bytes("emit, 1 argument", function() {
			var emitter = signals();
			return function() emitter.emit(S1, 1);
		});
		Bench.bytes("emit, 3 arguments", function() {
			var emitter = signals();
			var thing = new Thing();
			return function() emitter.emit(S3, 1, thing, 2);
		});
		Bench.bytes("emit, 1 Float argument", function() {
			var emitter = signals();
			return function() emitter.emit(SF, 0.5);
		});
	}
}

private class Thing {
	public function new() {}
}
