package;

import cases.*;

/**
	Emitter's tests. Built and run for one target by that target's hxml in
	this folder, for all of them by `haxe test/all.hxml`; utest exits with 1
	when anything fails.
**/
class TestMain {
	static function main() {
		utest.UTest.run([
			new EventObjectTest(),
			new EventListenerTest(),
			new DispatchTest(),
			new BubblingTest(),
			new MidDispatchTest(),
			new SignalTest(),
			new RemovalTest(),
			new ListenersChangedTest(),
			new LazyStorageTest(),
			new GraphaxeReliesOnTest()
		]);
	}
}
