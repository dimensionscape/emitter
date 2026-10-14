package;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

/**
	Builds the benchmark for each dispatcher and target, runs them
	interleaved, and prints a table per target:

	```
	haxe bench/all.hxml               # cpp, jvm and node
	haxe bench/all.hxml cpp           # those named
	```

	Run from the repository's root. Every case runs in a process of its
	own, on the jvm and Node with the young generation of the heap pinned,
	so that nothing one case or one dispatcher's start-up did changes what
	another measures. Three reps: in each, every dispatcher runs a case
	before the next case starts, so a slow spell of the machine falls on
	all of them alike. A figure is the median of the reps, each rep's being
	its best sample; the range of the reps follows it.

	The dispatchers compared, each built from its own source:
	- Emitter 2.0, this repository's `src`;
	- CrossByte's `EventDispatcher`, from `CROSSBYTE_SRC` (CrossByte's `src`);
	- Graphaxe's `EventEmitter`, from `GRAPHAXE_SRC` (Graphaxe's `src`);
	- Emitter 1.0.0, from the `v1.0.0` tag of this repository.
	One whose source is not given is left out. `BENCH_ONLY` names the ones
	to run, comma separated, to compare fewer while working on one.
**/
class RunBench {
	static final TARGETS = ["cpp", "jvm", "node"];
	static inline var REPS:Int = 3;

	static function main() {
		var targets = Sys.args().length > 0 ? Sys.args() : TARGETS;
		var subjects = subjectsFound();
		var only = Sys.getEnv("BENCH_ONLY");
		if (only != null && only != "") {
			var names = only.split(",");
			subjects = subjects.filter(s -> names.indexOf(s.name) >= 0);
		}
		for (target in targets) {
			for (subject in subjects) {
				build(subject, target);
			}
		}

		// Each case runs in a process of its own, so what a JIT learned from
		// one cannot slow or speed another; within a rep, every dispatcher runs
		// a case before the next case starts.
		var cases = new Map<String, Array<String>>(); // subject name + target -> its cases
		var order = new Map<String, Array<String>>(); // target -> every case, in order
		for (target in targets) {
			var all:Array<String> = [];
			for (subject in subjects) {
				var mine:Array<String> = [];
				for (line in lines(run(subject, target, ["--list"]))) {
					var parts = line.split("\t");
					if (parts.length == 2 && parts[0] == "CASE") {
						mine.push(parts[1]);
						if (all.indexOf(parts[1]) < 0) {
							all.push(parts[1]);
						}
					}
				}
				cases.set(subject.name + "@" + target, mine);
			}
			order.set(target, all);
		}

		// target -> subject -> case -> figures, one per rep
		var results = new Map<String, Map<String, Map<String, Array<Float>>>>();
		for (rep in 0...REPS) {
			for (target in targets) {
				Sys.println('rep ${rep + 1} on $target');
				var byTarget = results.get(target);
				if (byTarget == null) {
					results.set(target, byTarget = new Map());
				}
				for (name in order.get(target)) {
					for (subject in subjects) {
						if (cases.get(subject.name + "@" + target).indexOf(name) < 0) {
							continue;
						}
						for (line in lines(run(subject, target, [name]))) {
							var parts = line.split("\t");
							if (parts.length != 3 || parts[0] != "ROW") {
								continue;
							}
							var bySubject = byTarget.get(subject.name);
							if (bySubject == null) {
								byTarget.set(subject.name, bySubject = new Map());
							}
							var figures = bySubject.get(parts[1]);
							if (figures == null) {
								bySubject.set(parts[1], figures = []);
							}
							figures.push(Std.parseFloat(parts[2]));
						}
					}
				}
			}
		}

		var report = new StringBuf();
		for (target in targets) {
			var byTarget = results.get(target);
			if (byTarget == null) {
				continue;
			}
			report.add('\n### $target\n\n| case | ' + [for (s in subjects) s.name].join(" | ") + " |\n");
			report.add("|---|" + [for (_ in subjects) "---:"].join("|") + "|\n");
			for (name in order.get(target)) {
				var cells = [];
				for (subject in subjects) {
					var bySubject = byTarget.get(subject.name);
					var figures = bySubject == null ? null : bySubject.get(name);
					cells.push(figures == null ? "n/a" : cell(figures));
				}
				report.add('| $name | ' + cells.join(" | ") + " |\n");
			}
		}
		Sys.println(report.toString());
		FileSystem.createDirectory("bin/bench");
		File.saveContent("bin/bench/results.md", report.toString());
	}

	static function cell(figures:Array<Float>):String {
		var sorted = figures.copy();
		sorted.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		var median = sorted[sorted.length >> 1];
		var low = sorted[0];
		var high = sorted[sorted.length - 1];
		return low == high ? number(median) : number(median) + " (" + number(low) + "-" + number(high) + ")";
	}

	static function number(value:Float):String {
		return value >= 100 ? Std.string(Math.round(value)) : Std.string(Math.round(value * 10) / 10);
	}

	static function subjectsFound():Array<Subject> {
		var subjects:Array<Subject> = [{name: "Emitter 2", main: "EmitterCases", classPath: "src"}];
		var crossbyte = Sys.getEnv("CROSSBYTE_SRC");
		if (crossbyte != null && crossbyte != "") {
			subjects.push({name: "CrossByte", main: "CrossByteCases", classPath: crossbyte});
		} else {
			Sys.println("CROSSBYTE_SRC is not set: CrossByte's dispatcher is left out.");
		}
		var graphaxe = Sys.getEnv("GRAPHAXE_SRC");
		if (graphaxe != null && graphaxe != "") {
			subjects.push({name: "Graphaxe", main: "GraphaxeCases", classPath: graphaxe});
		} else {
			Sys.println("GRAPHAXE_SRC is not set: Graphaxe's emitter is left out.");
		}
		var old = "bin/bench/emitter1";
		if (!FileSystem.exists(old + "/src")) {
			FileSystem.createDirectory(old);
			// The 1.0.0 sources, read from this repository's history.
			var archive = new Process("git", ["archive", "--format=tar", "-o", old + "/v1.tar", "v1.0.0", "src"]);
			var code = archive.exitCode();
			archive.close();
			if (code == 0) {
				var untar = new Process("tar", ["-xf", old + "/v1.tar", "-C", old]);
				untar.exitCode();
				untar.close();
			}
		}
		if (FileSystem.exists(old + "/src")) {
			subjects.push({name: "Emitter 1", main: "Emitter1Cases", classPath: old + "/src"});
		} else {
			Sys.println("The v1.0.0 sources could not be read: Emitter 1 is left out.");
		}
		return subjects;
	}

	static function outputOf(subject:Subject, target:String):String {
		var dir = 'bin/bench/${subject.main}/$target';
		return switch (target) {
			case "cpp": dir;
			case "jvm": '$dir/bench.jar';
			default: '$dir/bench.js';
		}
	}

	static function binaryOf(subject:Subject, target:String):String {
		return switch (target) {
			case "cpp": outputOf(subject, target) + "/" + subject.main + (Sys.systemName() == "Windows" ? ".exe" : "");
			default: outputOf(subject, target);
		}
	}

	static function build(subject:Subject, target:String):Void {
		var binary = binaryOf(subject, target);
		if (FileSystem.exists(binary)) {
			FileSystem.deleteFile(binary);
		}
		var args = ["-cp", "bench", "-cp", subject.classPath, "-main", subject.main];
		switch (target) {
			case "cpp":
				args = args.concat(["-D", "HXCPP_M64", "--cpp", outputOf(subject, target)]);
			case "jvm":
				args = args.concat(["--jvm", outputOf(subject, target)]);
			case "node":
				args = args.concat(["-lib", "hxnodejs", "-js", outputOf(subject, target)]);
			default:
				throw 'Unknown target "$target": one of ${TARGETS.join(", ")}.';
		}
		Sys.println('build ${subject.name} for $target');
		var process = new Process("haxe", args);
		var out = process.stdout.readAll().toString() + process.stderr.readAll().toString();
		var code = process.exitCode();
		process.close();
		if (code != 0 || !FileSystem.exists(binary)) {
			Sys.println(out);
			throw 'The ${subject.name} benchmark did not build for $target.';
		}
	}

	static function lines(output:String):Array<String> {
		return output.replace("\r", "").split("\n");
	}

	static function run(subject:Subject, target:String, args:Array<String>):String {
		var binary = binaryOf(subject, target);
		var command = switch (target) {
			case "cpp": [Sys.systemName() == "Windows" ? FileSystem.absolutePath(binary).replace("/", "\\") : FileSystem.absolutePath(binary)];
			// The young generation is pinned: grown by whatever a program
			// allocated before (CrossByte's runtime starting, say), it makes
			// later allocation cheaper, and a case would measure that.
			case "jvm": ["java", "-Xms512m", "-Xmx512m", "-Xmn128m", "-jar", binary];
			default: ["node", "--min-semi-space-size=16", "--max-semi-space-size=16", binary];
		}
		var process = new Process(command[0], command.slice(1).concat(args));
		var out = process.stdout.readAll().toString();
		var err = process.stderr.readAll().toString();
		var code = process.exitCode();
		process.close();
		if (code != 0) {
			Sys.println(out + err);
			throw '${subject.name} failed on $target.';
		}
		return out;
	}
}

typedef Subject = {
	var name:String;
	var main:String;
	var classPath:String;
}
