package cases;

import emitter.Emitter;
import emitter.Event;
import emitter.EventType;
import emitter.Signal0;
import emitter.Signal1;
import emitter.Signal2;
import emitter.Signal3;
import emitter.Signal4;
import emitter.Signal5;
import support.Support;
import utest.Assert;
import utest.Test;

/** The signal lane: typed calls with no event object. **/
class SignalTest extends Test {
	static inline var S0:Signal0 = "s0";
	static inline var S1:Signal1<Int> = "s1";
	static inline var S2:Signal2<Int, String> = "s2";
	static inline var S3:Signal3<Int, String, Bool> = "s3";
	static inline var S4:Signal4<Int, String, Bool, Float> = "s4";
	static inline var S5:Signal5<Int, String, Bool, Float, Array<Int>> = "s5";
	static inline var SHARED_SIGNAL:Signal0 = "shared";
	static inline var SHARED_EVENT:EventType<Event> = "shared";

	function testEachArityIsCalledWithItsArguments() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(S0, function() log.push("0"));
		emitter.on(S1, function(a:Int) log.push("1:" + a));
		emitter.on(S2, function(a:Int, b:String) log.push('2:$a$b'));
		emitter.on(S3, function(a:Int, b:String, c:Bool) log.push('3:$a$b$c'));
		emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) log.push('4:$a$b$c$d'));
		emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push('5:$a$b$c$d${e.length}'));
		Assert.isTrue(emitter.emit(S0));
		Assert.isTrue(emitter.emit(S1, 1));
		Assert.isTrue(emitter.emit(S2, 2, "b"));
		Assert.isTrue(emitter.emit(S3, 3, "b", true));
		Assert.isTrue(emitter.emit(S4, 4, "b", false, 1.5));
		Assert.isTrue(emitter.emit(S5, 5, "b", true, 2.5, [1, 2]));
		Assert.equals("0,1:1,2:2b,3:3btrue,4:4bfalse1.5,5:5btrue2.52", log.join(","));
	}

	function testEachArityWalksSeveralListeners() {
		var emitter = new Emitter();
		var log = [];
		for (name in ["x", "y"]) {
			emitter.on(S0, function() log.push(name + "0"));
			emitter.on(S1, function(a:Int) log.push(name + a));
			emitter.on(S2, function(a:Int, b:String) log.push(name + a + b));
			emitter.on(S3, function(a:Int, b:String, c:Bool) log.push(name + a + b + c));
			emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) log.push(name + a + b + c + d));
			emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push(name + a + b + c + d + e.length));
		}
		emitter.emit(S0);
		emitter.emit(S1, 1);
		emitter.emit(S2, 2, "b");
		emitter.emit(S3, 3, "b", true);
		emitter.emit(S4, 4, "b", true, 0.5);
		emitter.emit(S5, 5, "b", true, 0.5, [7]);
		Assert.equals("x0,y0,x1,y1,x2b,y2b,x3btrue,y3btrue,x4btrue0.5,y4btrue0.5,x5btrue0.51,y5btrue0.51", log.join(","));
	}

	function testEmitSaysWhetherAnythingListened() {
		var emitter = new Emitter();
		Assert.isFalse(emitter.emit(S0));
		Assert.isFalse(emitter.emit(S1, 1));
		emitter.on(S2, function(a:Int, b:String) {});
		Assert.isFalse(emitter.emit(S1, 1));
		Assert.isTrue(emitter.emit(S2, 1, ""));
	}

	function testASignalListenerAddedTwiceIsCalledTwice() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function() calls++;
		emitter.on(S0, listener);
		emitter.on(S0, listener);
		emitter.emit(S0);
		Assert.equals(2, calls);
		emitter.off(S0, listener);
		emitter.emit(S0);
		Assert.equals(3, calls);
		emitter.off(S0, listener);
		Assert.isFalse(emitter.emit(S0));
	}

	function testPriorityAndPrependOrderSignalsAsEvents() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(S1, function(_) log.push("a"));
		emitter.on(S1, function(_) log.push("high"), 3);
		emitter.prepend(S1, function(_) log.push("first"));
		emitter.on(S1, function(_) log.push("low"), -3);
		emitter.emit(S1, 0);
		Assert.equals("high,first,a,low", log.join(","));
	}

	function testOffRemovesAndUnknownIsNothing() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(a:Int) calls += a;
		emitter.off(S1, listener);
		emitter.on(S1, listener);
		emitter.off(S1, function(_) {});
		emitter.emit(S1, 2);
		emitter.off(S1, listener);
		emitter.emit(S1, 2);
		Assert.equals(2, calls);
		Assert.isFalse(emitter.hasSignalListener(S1));
	}

	function testASignalAndAnEventMayShareAName() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(SHARED_SIGNAL, function() log.push("signal"));
		emitter.on(SHARED_EVENT, function(_) log.push("event"));
		emitter.emit(SHARED_SIGNAL);
		emitter.dispatchEvent(new Event(SHARED_EVENT));
		emitter.removeSignalListeners(SHARED_SIGNAL);
		Assert.isTrue(emitter.hasEventListener(SHARED_EVENT));
		Assert.isFalse(emitter.hasSignalListener(SHARED_SIGNAL));
		emitter.emit(SHARED_SIGNAL);
		emitter.dispatchEvent(new Event(SHARED_EVENT));
		Assert.equals("signal,event,event", log.join(","));
	}

	function testOnceNeedsNoArityAndRunsOnceForEach() {
		var emitter = new Emitter();
		var log = [];
		emitter.once(S0, function() log.push("0"));
		emitter.once(S1, function(a:Int) log.push("1:" + a));
		emitter.once(S2, function(a:Int, b:String) log.push('2:$a$b'));
		emitter.once(S3, function(a:Int, b:String, c:Bool) log.push('3:$a$b$c'));
		emitter.once(S4, function(a:Int, b:String, c:Bool, d:Float) log.push('4:$a$b$c$d'));
		emitter.once(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push('5:$a$b$c$d${e.length}'));
		for (_ in 0...2) {
			emitter.emit(S0);
			emitter.emit(S1, 1);
			emitter.emit(S2, 2, "b");
			emitter.emit(S3, 3, "b", true);
			emitter.emit(S4, 4, "b", true, 0.5);
			emitter.emit(S5, 5, "b", true, 0.5, []);
		}
		Assert.equals("0,1:1,2:2b,3:3btrue,4:4btrue0.5,5:5btrue0.50", log.join(","));
		for (signal in [(S0 : String), S1, S2, S3, S4, S5]) {
			Assert.isFalse(emitter.hasSignalListener(signal));
		}
	}

	function testOnceAmongOthersRunsOnceAndTheOthersStay() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(S1, function(a) log.push("a" + a));
		emitter.once(S1, function(a) log.push("once" + a));
		emitter.on(S1, function(a) log.push("b" + a));
		emitter.emit(S1, 1);
		emitter.emit(S1, 2);
		Assert.equals("a1,once1,b1,a2,b2", log.join(","));
		Assert.equals(0, Inside.signalWalks(emitter));
	}

	function testOffCancelsASignalOnce() {
		var emitter = new Emitter();
		var calls = 0;
		var listener = function(a:Int, b:String) calls++;
		emitter.once(S2, listener);
		emitter.off(S2, listener);
		Assert.isFalse(emitter.emit(S2, 1, ""));
		Assert.equals(0, calls);
	}

	function testChangesDuringAnEmitWaitForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var b = function(a:Int) log.push("b");
		var added = false;
		emitter.on(S1, function(_) {
			log.push("a");
			emitter.off(S1, b);
			if (!added) {
				added = true;
				emitter.on(S1, function(_) log.push("late"));
			}
		});
		emitter.on(S1, b);
		emitter.emit(S1, 0);
		Assert.equals("a,b", log.join(","));
		emitter.emit(S1, 0);
		Assert.equals("a,b,a,late", log.join(","));
	}

	function testListenersAddedAheadDuringAnEmitWaitForTheNext() {
		var emitter = new Emitter();
		var log = [];
		var once = true;
		emitter.on(S1, function(_) {
			log.push("a");
			if (once) {
				once = false;
				emitter.on(S1, function(_) log.push("high"), 10);
				emitter.prepend(S1, function(_) log.push("first"));
			}
		});
		emitter.on(S1, function(_) log.push("b"));
		emitter.emit(S1, 0);
		Assert.equals("a,b", log.join(","));
		log = [];
		emitter.emit(S1, 0);
		Assert.equals("high,first,a,b", log.join(","));
	}

	function testASignalListenerMayRemoveItself() {
		var emitter = new Emitter();
		var calls = 0;
		var self:Void->Void = null;
		self = function() {
			calls++;
			emitter.off(S0, self);
		};
		emitter.on(S0, self);
		emitter.emit(S0);
		emitter.emit(S0);
		Assert.equals(1, calls);
	}

	function testAThrowDuringAnEmitReachesTheCallerAndTheCountIsPutBack() {
		var emitter = new Emitter();
		var thrown = new haxe.Exception("signal");
		emitter.on(S1, function(_) {});
		emitter.on(S1, function(_) throw thrown);
		var caught:Null<haxe.Exception> = null;
		try {
			emitter.emit(S1, 1);
		} catch (e:haxe.Exception) {
			caught = e;
		}
		Assert.equals(thrown, caught);
		Assert.equals(0, Inside.signalWalks(emitter));

		var only = new Emitter();
		only.on(S0, function() throw thrown);
		caught = null;
		try {
			only.emit(S0);
		} catch (e:haxe.Exception) {
			caught = e;
		}
		Assert.equals(thrown, caught);
	}

	function testHasSignalListenerIsExact() {
		var emitter = new Emitter();
		var a = function(x:Int) {};
		var b = function(x:Int) {};
		Assert.isFalse(emitter.hasSignalListener(S1));
		emitter.on(S1, a);
		Assert.isTrue(emitter.hasSignalListener(S1));
		Assert.isTrue(emitter.hasSignalListener(S1, a));
		Assert.isFalse(emitter.hasSignalListener(S1, b));
		emitter.off(S1, a);
		Assert.isFalse(emitter.hasSignalListener(S1));
	}

	function testRemoveSignalListenersOfOneOrAll() {
		var emitter = new Emitter();
		emitter.on(S0, function() {});
		emitter.on(S1, function(_) {});
		emitter.removeSignalListeners(S0);
		Assert.isFalse(emitter.hasSignalListener(S0));
		Assert.isTrue(emitter.hasSignalListener(S1));
		emitter.removeSignalListeners();
		Assert.isFalse(emitter.hasSignalListener(S1));
		Assert.isFalse(emitter.emit(S1, 1));
	}

	function testANullSignalOrListenerIsRefused() {
		var emitter = new Emitter();
		var nothing:Void->Void = null;
		Assert.raises(() -> emitter.on(S0, nothing), haxe.exceptions.ArgumentException);
		var noSignal:Signal0 = null;
		Assert.raises(() -> emitter.on(noSignal, function() {}), haxe.exceptions.ArgumentException);
		emitter.off(S0, nothing);
		Assert.isFalse(emitter.hasSignalListener(S0));
	}

	function testSignalsDoNotReportListenersChanged() {
		var emitter = new Recording();
		var listener = function() {};
		emitter.on(S0, listener);
		emitter.off(S0, listener);
		emitter.once(S0, listener);
		emitter.emit(S0);
		emitter.on(S0, listener);
		emitter.removeAllListeners();
		Assert.equals("", emitter.log());
	}

	function testSignalsChainOnTheEmitter() {
		var emitter = new Emitter();
		var listener = function(a:Int) {};
		Assert.equals(emitter, emitter.on(S1, listener).prepend(S1, listener).once(S1, listener).off(S1, listener));
	}
}
