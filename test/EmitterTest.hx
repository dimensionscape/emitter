package;

import utest.Test;
import utest.Assert;
import emitter.Emitter;
import emitter.signals.Arity;
import emitter.signals.SignalType;

class EmitterTest extends Test {
    public function testEmit():Void {
        var emitter = new Emitter();
        var fired = false;

        emitter.on("ping", function() fired = true);
        emitter.emit("ping");

        Assert.isTrue(fired);
    }

    public function testOff():Void {
        var emitter = new Emitter();
        var count = 0;
        var cb = function() count++;

        emitter.on("test", cb);
        emitter.off("test", cb);
        emitter.emit("test");

        Assert.equals(0, count);
    }

    public function testOnce():Void {
        var emitter = new Emitter();
        var count = 0;
        final sig:SignalType<Void->Void> = "once";

        emitter.once(sig, function() count++, Arity.Zero);
        emitter.emit(sig);
        emitter.emit(sig);

        Assert.equals(1, count);
    }

    public function testCounts():Void {
        var emitter = new Emitter();

        emitter.on("a", function() {});
        emitter.on("a", function() {});
        emitter.on("b", function() {});

        Assert.equals(2, emitter.callbackCount("a"));
        Assert.equals(2, emitter.signalCount());
        Assert.equals(3, emitter.totalCallbacks());
    }

    public function testPrependOrder():Void {
        var emitter = new Emitter();
        var order = "";

        emitter.on("order", function() order += "2");
        emitter.prepend("order", function() order += "1");
        emitter.emit("order");

        Assert.equals("12", order);
    }

    public function testRemoveCallbacksAndHasSignal():Void {
        var emitter = new Emitter();
        var triggered = false;

        emitter.on("boom", function() triggered = true);
        Assert.isTrue(emitter.hasSignal("boom"));
        emitter.removeCallbacks("boom");
        Assert.isFalse(emitter.hasSignal("boom"));
        emitter.emit("boom");

        Assert.isFalse(triggered);
    }

    public function testEmitWithArgs():Void {
        var emitter = new Emitter();
        var result = 0;
        final sig:SignalType2<(Int, Int)->Void, Int, Int> = "sum";

        emitter.on(sig, function(a:Int, b:Int) result = a + b);
        emitter.emit(sig, 2, 3);

        Assert.equals(5, result);
    }

    public function testEmitUntyped():Void {
        var emitter = new Emitter();
        var args:Array<Dynamic> = [];

        emitter.on("varargs", function(a:Dynamic, b:Dynamic, c:Dynamic) {
            args = [a, b, c];
        });
        emitter.emitUntyped("varargs", "a", 2, true);

        Assert.equals("a", args[0]);
        Assert.equals(2, args[1]);
        Assert.equals(true, args[2]);
    }

    public function testDispose():Void {
        var emitter = new Emitter();
        var triggered = false;

        emitter.on("ping", function() triggered = true);
        Assert.isTrue(emitter.isReady);
        emitter.dispose();
        Assert.isFalse(emitter.isReady);
        emitter.emit("ping");
        Assert.isFalse(triggered);

        emitter.on("ping", function() triggered = true);
        emitter.emit("ping");
        Assert.isTrue(triggered);
    }

    public function testOnceArityOne():Void {
        var emitter = new Emitter();
        var value = 0;
        final sig:SignalType1<Int->Void, Int> = "once1";

        emitter.once(sig, function(a:Int) value = a, Arity.One);
        emitter.emit(sig, 7);
        emitter.emit(sig, 9);

        Assert.equals(7, value);
    }

    public function testOnceArityTwo():Void {
        var emitter = new Emitter();
        var sum = 0;
        final sig:SignalType2<(Int, Int)->Void, Int, Int> = "once2";

        emitter.once(sig, function(a:Int, b:Int) sum = a + b, Arity.Two);
        emitter.emit(sig, 3, 4);
        emitter.emit(sig, 5, 6);

        Assert.equals(7, sum);
    }

    public function testOnceArityThree():Void {
        var emitter = new Emitter();
        var sum = 0;
        final sig:SignalType3<(Int, Int, Int)->Void, Int, Int, Int> = "once3";

        emitter.once(sig, function(a:Int, b:Int, c:Int) sum = a + b + c, Arity.Three);
        emitter.emit(sig, 1, 2, 3);
        emitter.emit(sig, 4, 5, 6);

        Assert.equals(6, sum);
    }

    public function testOnceArityFour():Void {
        var emitter = new Emitter();
        var sum = 0;
        final sig:SignalType4<(Int, Int, Int, Int)->Void, Int, Int, Int, Int> = "once4";

        emitter.once(sig, function(a:Int, b:Int, c:Int, d:Int) sum = a + b + c + d, Arity.Four);
        emitter.emit(sig, 1, 2, 3, 4);
        emitter.emit(sig, 5, 6, 7, 8);

        Assert.equals(10, sum);
    }

    public function testOnceArityFive():Void {
        var emitter = new Emitter();
        var sum = 0;
        final sig:SignalType5<(Int, Int, Int, Int, Int)->Void, Int, Int, Int, Int, Int> = "once5";

        emitter.once(sig, function(a:Int, b:Int, c:Int, d:Int, e:Int) sum = a + b + c + d + e, Arity.Five);
        emitter.emit(sig, 1, 2, 3, 4, 5);
        emitter.emit(sig, 6, 7, 8, 9, 10);

        Assert.equals(15, sum);
    }

    public function testOnceVarArgs():Void {
        var emitter = new Emitter();
        var args:Array<Dynamic> = [];

        emitter.once("va", function(a:Dynamic, b:Dynamic, c:Dynamic) args = [a, b, c], Arity.VarArgs);
        emitter.emitUntyped("va", 1, "two", true);
        emitter.emitUntyped("va", 4, 5, 6);

        Assert.equals(3, args.length);
        Assert.equals(1, args[0]);
        Assert.equals("two", args[1]);
        Assert.equals(true, args[2]);
    }
}
