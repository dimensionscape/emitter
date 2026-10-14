package;

/**
	The benchmark's harness, shared by every dispatcher it measures, so the
	numbers compare like for like.

	**Time.** Read from the harness's own clock (`now`). A case runs
	`INNER` operations per call, so the cost of calling the case is spread
	thin, and alternates between two of what it measures, so that an
	optimiser cannot lift a query about one object out of the loop. It is calibrated until a sample takes about 0.1 s, then timed
	`SAMPLES` times, and the best sample is reported: on a machine doing
	anything else, noise only adds time, so the fastest observation is the
	closest to what the code costs.

	**Allocation.** Natively and on the jvm, `bytes` reads what one
	operation allocates (see `AllocationMeter`); elsewhere nothing is read.

	Each line printed is `ROW`, the case, and the figure, tab separated, for
	`RunBench` to collect.
**/
class Bench {
	public static inline var INNER:Int = 100;

	static inline var TARGET_SAMPLE:Float = 0.1;
	static inline var SAMPLES:Int = 5;

	/** Something each listener writes, so no listener is empty. **/
	public static var sink:Int = 0;

	/** Where an object made by a case is kept, so it is not optimised away. **/
	public static var kept:Dynamic = null;

	/**
		Whether to run the case `name` in this process: `RunBench` runs each
		case in a process of its own, naming it on the command line, so that
		what a JIT learned from one case cannot slow or speed another. With
		`--list`, names it instead.
	**/
	static function selected(name:String):Bool {
		var args = Sys.args();
		if (args.length == 0) {
			return true;
		}
		if (args[0] == "--list") {
			Sys.println("CASE\t" + name);
			return false;
		}
		return args[0] == name;
	}

	/**
		Times the operation `make` builds, which performs `INNER` operations;
		prints nanoseconds per operation. `make` builds the case's objects
		too, so a process running one case makes only what that case uses.
	**/
	public static function time(name:String, make:Void->(Void->Void)):Void {
		if (!selected("ns " + name)) {
			return;
		}
		var op = make();
		var reps = 1;
		while (true) {
			var t0 = now();
			for (_ in 0...reps) {
				op();
			}
			var elapsed = now() - t0;
			if (elapsed >= 0.01) {
				reps = Std.int(Math.max(1, reps * TARGET_SAMPLE / elapsed));
				break;
			}
			reps *= 2;
		}
		var best = Math.POSITIVE_INFINITY;
		for (_ in 0...SAMPLES) {
			var t0 = now();
			for (_ in 0...reps) {
				op();
			}
			var elapsed = now() - t0;
			if (elapsed < best) {
				best = elapsed;
			}
		}
		row("ns " + name, best / (reps * INNER) * 1e9);
	}

	/**
		Reads what one call of the operation `make` builds allocates; prints
		bytes. Natively and on the jvm only.
	**/
	public static function bytes(name:String, make:Void->(Void->Void)):Void {
		#if (cpp || jvm)
		if (!selected("bytes " + name)) {
			return;
		}
		var op = make();
		for (_ in 0...20000) {
			op();
		}
		row("bytes " + name, AllocationMeter.measure(op, 20000));
		#end
	}

	/**
		Seconds from a monotonic clock of the harness's own: the same for every
		dispatcher measured, whatever its sources make of `haxe.Timer`
		(CrossByte's replace it).
	**/
	static inline function now():Float {
		#if cpp
		return untyped __global__.__time_stamp();
		#elseif jvm
		var nanos:haxe.Int64 = java.lang.System.nanoTime();
		var low:Float = nanos.low;
		if (low < 0) {
			low += 4294967296.0;
		}
		return (nanos.high * 4294967296.0 + low) / 1e9;
		#elseif nodejs
		var time:Array<Float> = js.Syntax.code("process.hrtime()");
		return time[0] + time[1] / 1e9;
		#else
		return Sys.time();
		#end
	}

	static function row(name:String, value:Float):Void {
		Sys.println("ROW\t" + name + "\t" + (Math.round(value * 10) / 10));
	}
}
