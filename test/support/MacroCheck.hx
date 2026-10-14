package support;

/**
	Uses an emitter inside the build's macros, which run on eval with the
	target defined, and some of the target's own packages out of reach: a
	jvm build's macros cannot type `java.NativeString`. A framework whose
	macros touch its events (CrossByte's do) builds only if Emitter types
	there, and one that keeps an emitter at
	compile time needs it to work there. Run on every target by
	`test/common.hxml`; a wrong answer stops the build.
**/
class MacroCheck {
	public static function run():Void {
		#if macro
		var emitter = new emitter.Emitter();
		var heard:Array<String> = [];
		emitter.on("ping", function(event:emitter.Event):Void {
			heard.push(event.type);
		});
		var subscriptions = [];
		// Past the names a lane chains, into its map, and back.
		for (i in 0...10) {
			subscriptions.push(emitter.on("t" + i, function(_:emitter.Event):Void {}));
		}
		emitter.dispatch(new emitter.Event("ping"));
		emitter.dispatch(new emitter.Event(["pi", "ng"].join("")));
		var missed:Bool = emitter.dispatch(new emitter.Event("pong"));
		for (subscription in subscriptions) {
			subscription.cancel();
		}
		var thrown:Dynamic = null;
		emitter.on("boom", function(_:emitter.Event):Void {
			throw "boom";
		});
		try {
			emitter.dispatch(new emitter.Event("boom"));
		} catch (error:Dynamic) {
			thrown = error;
		}
		var values:Array<Int> = [];
		var signal:emitter.Signal1<Int> = "value";
		emitter.on(signal, function(v:Int):Void {
			values.push(v);
		});
		emitter.emit(signal, 3);
		if (heard.join(",") != "ping,ping" || missed || emitter.has("t3") || !emitter.has("ping") || Std.string(thrown) != "boom"
			|| values.join(",") != "3") {
			haxe.macro.Context.fatalError("An emitter in the build's macros answered wrongly: heard " + heard.join(",") + ", missed " + missed
				+ ", threw " + Std.string(thrown) + ", values " + values.join(","),
				haxe.macro.Context.currentPos());
		}
		#end
	}
}
