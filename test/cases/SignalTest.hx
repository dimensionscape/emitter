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

	function testPriorityOrdersSignalsAsEvents() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(S1, function(_) log.push("a"));
		emitter.on(S1, function(_) log.push("high"), 3);
		emitter.on(S1, function(_) log.push("b"));
		emitter.on(S1, function(_) log.push("low"), -3);
		emitter.emit(S1, 0);
		Assert.equals("high,a,b,low", log.join(","));
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
		Assert.isFalse(emitter.has(S1));
	}

	function testASignalAndAnEventMayShareAName() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(SHARED_SIGNAL, function() log.push("signal"));
		emitter.on(SHARED_EVENT, function(_) log.push("event"));
		emitter.emit(SHARED_SIGNAL);
		emitter.dispatch(new Event(SHARED_EVENT));
		emitter.clear(SHARED_SIGNAL);
		Assert.isTrue(emitter.has(SHARED_EVENT));
		Assert.isFalse(emitter.has(SHARED_SIGNAL));
		emitter.emit(SHARED_SIGNAL);
		emitter.dispatch(new Event(SHARED_EVENT));
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
		// Each by its own token: a plain string would ask about events.
		Assert.isFalse(emitter.has(S0));
		Assert.isFalse(emitter.has(S1));
		Assert.isFalse(emitter.has(S2));
		Assert.isFalse(emitter.has(S3));
		Assert.isFalse(emitter.has(S4));
		Assert.isFalse(emitter.has(S5));
	}

	function testAOnceBetweenOthersRunsOnceAndTheNextStillRunsAtEachArity() {
		var emitter = new Emitter();
		var log = [];
		emitter.on(S0, function() log.push("a0"));
		emitter.once(S0, function() log.push("o0"));
		emitter.on(S0, function() log.push("b0"));
		emitter.on(S1, function(a:Int) log.push("a1"));
		emitter.once(S1, function(a:Int) log.push("o1"));
		emitter.on(S1, function(a:Int) log.push("b1"));
		emitter.on(S2, function(a:Int, b:String) log.push("a2"));
		emitter.once(S2, function(a:Int, b:String) log.push("o2"));
		emitter.on(S2, function(a:Int, b:String) log.push("b2"));
		emitter.on(S3, function(a:Int, b:String, c:Bool) log.push("a3"));
		emitter.once(S3, function(a:Int, b:String, c:Bool) log.push("o3"));
		emitter.on(S3, function(a:Int, b:String, c:Bool) log.push("b3"));
		emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) log.push("a4"));
		emitter.once(S4, function(a:Int, b:String, c:Bool, d:Float) log.push("o4"));
		emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) log.push("b4"));
		emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push("a5"));
		emitter.once(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push("o5"));
		emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push("b5"));
		for (_ in 0...2) {
			emitter.emit(S0);
			emitter.emit(S1, 1);
			emitter.emit(S2, 2, "b");
			emitter.emit(S3, 3, "b", true);
			emitter.emit(S4, 4, "b", true, 0.5);
			emitter.emit(S5, 5, "b", true, 0.5, []);
		}
		Assert.equals("a0,o0,b0,a1,o1,b1,a2,o2,b2,a3,o3,b3,a4,o4,b4,a5,o5,b5,a0,b0,a1,b1,a2,b2,a3,b3,a4,b4,a5,b5", log.join(","));
	}

	function testAOnceANestedEmitReachedFirstIsPassedOverAtEachArity() {
		// The outer emit holds the once in the list it walks, spent by the
		// nested one: it passes over it to the listener after it.
		var emitter = new Emitter();
		var log = [];
		var nested = false;
		emitter.on(S0, function() if (!nested) {
			nested = true;
			emitter.emit(S0);
		});
		emitter.once(S0, function() log.push("once0"));
		emitter.on(S0, function() log.push("last0"));
		emitter.emit(S0);
		nested = false;
		emitter.on(S1, function(a:Int) if (!nested) {
			nested = true;
			emitter.emit(S1, a);
		});
		emitter.once(S1, function(a:Int) log.push("once1"));
		emitter.on(S1, function(a:Int) log.push("last1"));
		emitter.emit(S1, 1);
		nested = false;
		emitter.on(S2, function(a:Int, b:String) if (!nested) {
			nested = true;
			emitter.emit(S2, a, b);
		});
		emitter.once(S2, function(a:Int, b:String) log.push("once2"));
		emitter.on(S2, function(a:Int, b:String) log.push("last2"));
		emitter.emit(S2, 2, "b");
		nested = false;
		emitter.on(S3, function(a:Int, b:String, c:Bool) if (!nested) {
			nested = true;
			emitter.emit(S3, a, b, c);
		});
		emitter.once(S3, function(a:Int, b:String, c:Bool) log.push("once3"));
		emitter.on(S3, function(a:Int, b:String, c:Bool) log.push("last3"));
		emitter.emit(S3, 3, "b", true);
		nested = false;
		emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) if (!nested) {
			nested = true;
			emitter.emit(S4, a, b, c, d);
		});
		emitter.once(S4, function(a:Int, b:String, c:Bool, d:Float) log.push("once4"));
		emitter.on(S4, function(a:Int, b:String, c:Bool, d:Float) log.push("last4"));
		emitter.emit(S4, 4, "b", true, 0.5);
		nested = false;
		emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) if (!nested) {
			nested = true;
			emitter.emit(S5, a, b, c, d, e);
		});
		emitter.once(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push("once5"));
		emitter.on(S5, function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) log.push("last5"));
		emitter.emit(S5, 5, "b", true, 0.5, []);
		Assert.equals("once0,last0,last0,once1,last1,last1,once2,last2,last2,once3,last3,last3,once4,last4,last4,once5,last5,last5",
			log.join(","));
		Assert.equals(0, Inside.signalWalks(emitter));
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
				emitter.on(S1, function(_) log.push("first"), 1);
			}
		});
		emitter.on(S1, function(_) log.push("b"));
		emitter.emit(S1, 0);
		Assert.equals("a,b", log.join(","));
		log = [];
		emitter.emit(S1, 0);
		Assert.equals("high,first,a,b", log.join(","));
	}

	function testNamesAlikeAreFoundAndAnAbsentOneIsAMiss() {
		// Alike in length and in their first and last characters, as far as
		// can be: what tells an absent name at once must not hide a present
		// one. Three names stay chained everywhere; eight pass into a map on
		// the jvm and JavaScript.
		for (names in [["ab", "ac", "ad"], ["s0", "s1", "s2", "s3", "sa", "sb", "sz", "s9"]]) {
			var emitter = new Emitter();
			var log = [];
			var absent:Signal1<Int> = "zz";
			for (name in names) {
				var signal:Signal1<Int> = name;
				emitter.on(signal, function(v:Int) log.push(name + v));
				// A miss now, so what tells a miss is made before the next name
				// comes; the name just added, its text built at run time, is
				// still found.
				Assert.isFalse(emitter.has(absent));
				var built:Signal1<Int> = [for (i in 0...name.length) name.charAt(i)].join("");
				Assert.isTrue(emitter.has(built));
			}
			for (name in names) {
				var signal:Signal1<Int> = name;
				Assert.isTrue(emitter.emit(signal, 1));
				var built:Signal1<Int> = [for (i in 0...name.length) name.charAt(i)].join("");
				Assert.isTrue(emitter.has(built));
			}
			Assert.equals([for (name in names) name + "1"].join(","), log.join(","));
			for (absent in ["sn", "ae", "s", "s00", "t0", "", "S0", "ba"]) {
				var signal:Signal1<Int> = absent;
				Assert.isFalse(emitter.emit(signal, 1));
				Assert.isFalse(emitter.has(signal));
			}
			// Taking names out leaves the others found and the gone ones missed.
			for (i in 0...names.length) {
				if (i % 2 == 0) {
					emitter.clear((names[i] : Signal1<Int>));
				}
			}
			for (i in 0...names.length) {
				var signal:Signal1<Int> = names[i];
				Assert.equals(i % 2 == 1, emitter.emit(signal, 2));
			}
		}
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
		Assert.isFalse(emitter.has(S1));
		emitter.on(S1, a);
		Assert.isTrue(emitter.has(S1));
		Assert.isTrue(emitter.has(S1, a));
		Assert.isFalse(emitter.has(S1, b));
		emitter.off(S1, a);
		Assert.isFalse(emitter.has(S1));
	}

	function testHasAsksAboutOneListenerAtEachArity() {
		var emitter = new Emitter();
		var f0 = function() {};
		var f1 = function(a:Int) {};
		var f2 = function(a:Int, b:String) {};
		var f3 = function(a:Int, b:String, c:Bool) {};
		var f4 = function(a:Int, b:String, c:Bool, d:Float) {};
		var f5 = function(a:Int, b:String, c:Bool, d:Float, e:Array<Int>) {};
		Assert.isFalse(emitter.has(S0) || emitter.has(S1) || emitter.has(S5));
		emitter.on(S0, f0);
		emitter.on(S1, f1);
		emitter.on(S2, f2);
		emitter.on(S3, f3);
		emitter.on(S4, f4);
		emitter.on(S5, f5);
		Assert.isTrue(emitter.has(S0) && emitter.has(S0, f0));
		Assert.isTrue(emitter.has(S1) && emitter.has(S1, f1));
		Assert.isTrue(emitter.has(S2) && emitter.has(S2, f2));
		Assert.isTrue(emitter.has(S3) && emitter.has(S3, f3));
		Assert.isTrue(emitter.has(S4) && emitter.has(S4, f4));
		Assert.isTrue(emitter.has(S5) && emitter.has(S5, f5));
		Assert.isFalse(emitter.has(S1, function(a:Int) {}));
		emitter.off(S3, f3);
		Assert.isFalse(emitter.has(S3, f3));
		Assert.isFalse(emitter.has(S3));
		Assert.isFalse(emitter.has(SHARED_EVENT));
	}

	function testRemoveSignalListenersOfOneOrAll() {
		var emitter = new Emitter();
		emitter.on(S0, function() {});
		emitter.on(S1, function(_) {});
		emitter.clear(S0);
		Assert.isFalse(emitter.has(S0));
		Assert.isTrue(emitter.has(S1));
		emitter.clear();
		Assert.isFalse(emitter.has(S1));
		Assert.isFalse(emitter.emit(S1, 1));
	}

	function testANullSignalOrListenerIsRefused() {
		var emitter = new Emitter();
		var nothing:Void->Void = null;
		Assert.raises(() -> emitter.on(S0, nothing), haxe.exceptions.ArgumentException);
		var noSignal:Signal0 = null;
		Assert.raises(() -> emitter.on(noSignal, function() {}), haxe.exceptions.ArgumentException);
		emitter.off(S0, nothing);
		Assert.isFalse(emitter.has(S0));
	}

	function testSignalsDoNotReportListenersChanged() {
		var emitter = new Recording();
		var listener = function() {};
		emitter.on(S0, listener);
		emitter.off(S0, listener);
		emitter.once(S0, listener);
		emitter.emit(S0);
		emitter.on(S0, listener);
		emitter.clear();
		Assert.equals("", emitter.log());
	}

	function testASignalSubscriptionRemovesItsOwnListener() {
		// A signal listener added twice is two listeners: each subscription
		// removes its own, where off removes the first.
		var emitter = new Emitter();
		var log = [];
		var listener = function(a:Int) log.push("listener" + a);
		var first = emitter.on(S1, listener);
		var second = emitter.on(S1, listener, 1);
		Assert.notEquals(first, second);
		first.cancel();
		Assert.isFalse(first.active);
		Assert.isTrue(second.active);
		emitter.emit(S1, 1);
		Assert.equals("listener1", log.join(","));
		second.cancel();
		Assert.isFalse(emitter.emit(S1, 2));
	}

	function testASignalAndAnEventOfOneNameAreClearedApart() {
		var emitter = new Emitter();
		var signal = emitter.on(SHARED_SIGNAL, function() {});
		var event = emitter.on(SHARED_EVENT, function(_) {});
		emitter.clear(SHARED_SIGNAL);
		Assert.isFalse(signal.active);
		Assert.isTrue(event.active);
		event.cancel();
		Assert.isFalse(emitter.has(SHARED_EVENT));
	}
}
