package;

import utest.Test;
import utest.Assert;
import emitter.Emitter;

class EmitterTest extends Test {
    public function testEmit():Void {
        var emitter = new Emitter();
        var fired = false;

        emitter.on("ping", function() fired = true);
        emitter.emit("ping");

        Assert.isTrue(fired);
    }
}
