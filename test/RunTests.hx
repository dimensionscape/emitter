package;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

/**
	Builds and runs the tests on each target, and says how each went:

	```
	haxe test/all.hxml                 # every target
	haxe test/all.hxml eval node jvm   # those named
	```

	Run from the repository's root. Each target's output is kept in
	`bin/test/<target>.log`. A target's old binary is deleted before it is
	built, so a build that fails cannot leave the last one to run green.
	The runtimes come from the PATH; `HL` and `NEKO` name `hl` and `neko`
	when they are elsewhere.
**/
class RunTests {
	static final ALL = ["eval", "node", "jvm", "cpp", "hl", "neko"];

	static function main() {
		var targets = Sys.args().length > 0 ? Sys.args() : ALL;
		var rows = [];
		var failed = false;
		for (target in targets) {
			if (ALL.indexOf(target) < 0) {
				Sys.println('Unknown target "$target": one of ${ALL.join(", ")}.');
				Sys.exit(2);
			}
			var row = runTarget(target);
			rows.push(row);
			if (!row.ok) {
				failed = true;
			}
		}
		Sys.println("");
		Sys.println(pad("target", 8) + pad("result", 10) + pad("assertions", 12) + pad("successes", 11) + pad("failures", 10) + "errors");
		for (row in rows) {
			Sys.println(pad(row.target, 8) + pad(row.ok ? "ok" : row.note, 10) + pad(row.assertions, 12) + pad(row.successes, 11) + pad(row.failures, 10)
				+ row.errors);
		}
		Sys.exit(failed ? 1 : 0);
	}

	static function runTarget(target:String):Row {
		Sys.println('== $target');
		var binary = binaryOf(target);
		if (binary != null && FileSystem.exists(binary)) {
			FileSystem.deleteFile(binary);
		}
		var build = run("haxe", ['test/$target.hxml']);
		var output = build.output;
		if (build.code != 0) {
			File.saveContent('bin/test/$target.log', output);
			Sys.println(output);
			return row(target, target == "eval" ? output : "", target == "eval" ? "failed" : "no build");
		}
		if (target != "eval") {
			var command = commandOf(target, binary);
			var result = run(command[0], command.slice(1));
			output = result.output;
			if (result.code != 0) {
				FileSystem.createDirectory("bin/test");
				File.saveContent('bin/test/$target.log', output);
				Sys.println(output);
				return row(target, output, "failed");
			}
		}
		FileSystem.createDirectory("bin/test");
		File.saveContent('bin/test/$target.log', output);
		var result = row(target, output, "ok");
		if (result.failures != "0" || result.errors != "0" || result.assertions == "?") {
			result.ok = false;
			result.note = "failed";
			Sys.println(output);
		}
		return result;
	}

	static function binaryOf(target:String):Null<String> {
		return switch (target) {
			case "node": "bin/test/node/test.js";
			case "jvm": "bin/test/jvm/test.jar";
			case "cpp": "bin/test/cpp/TestMain" + (Sys.systemName() == "Windows" ? ".exe" : "");
			case "hl": "bin/test/hl/test.hl";
			case "neko": "bin/test/neko/test.n";
			default: null;
		}
	}

	static function commandOf(target:String, binary:String):Array<String> {
		return switch (target) {
			case "node": ["node", binary];
			case "jvm": ["java", "-jar", binary];
			case "hl": [tool("HL", "hl"), binary];
			case "neko": [tool("NEKO", "neko"), binary];
			default: [native(FileSystem.absolutePath(binary))];
		}
	}

	/** A path as the system writes it: Windows starts a program by its own separators. **/
	static function native(path:String):String {
		return Sys.systemName() == "Windows" ? path.replace("/", "\\") : path;
	}

	static function tool(variable:String, fallback:String):String {
		var named = Sys.getEnv(variable);
		return named != null && named != "" ? named : fallback;
	}

	static function run(command:String, args:Array<String>):{code:Int, output:String} {
		var process = new Process(command, args);
		var out = process.stdout.readAll().toString();
		var err = process.stderr.readAll().toString();
		var code = process.exitCode();
		process.close();
		return {code: code, output: out + err};
	}

	static function row(target:String, output:String, note:String):Row {
		return {
			target: target,
			ok: note == "ok",
			note: note,
			assertions: count(output, "assertations"),
			successes: count(output, "successes"),
			failures: count(output, "failures"),
			errors: count(output, "errors")
		};
	}

	static function count(output:String, label:String):String {
		var pattern = new EReg("^" + label + ": (\\d+)", "m");
		return pattern.match(output.replace("\r", "")) ? pattern.matched(1) : "?";
	}

	static function pad(text:String, width:Int):String {
		return text.rpad(" ", width);
	}
}

typedef Row = {
	var target:String;
	var ok:Bool;
	var note:String;
	var assertions:String;
	var successes:String;
	var failures:String;
	var errors:String;
}
