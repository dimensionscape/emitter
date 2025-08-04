package;

import utest.Test;
import utest.Assert;
import emitter.Emitter;
import emitter.signals.Arity;

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

        emitter.once("once", function() count++, Arity.Zero);
        emitter.emit("once");
        emitter.emit("once");

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

        emitter.on("sum", function(a:Int, b:Int) result = a + b);
        emitter.emit("sum", 2, 3);

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
}
