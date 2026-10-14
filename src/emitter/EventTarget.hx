package emitter;

/**
	An event's `target` or `currentTarget`: the `IEmitter` it was dispatched
	on, which a listener takes as the class it is without a cast.

	```haxe
	player.events.on(Event.CHANGE, function(event:Event):Void {
		var changed:Player = event.target;
	});
	```

	It converts to any class or interface built on `IEmitter` as `cast`
	does: taken as a class it is not, it goes wrong as a wrong cast does,
	and `Std.downcast(event.target, Player)` answers null instead. A class
	that is no emitter at all does not compile. At run time it is the
	`IEmitter` itself: nothing is made for it, and taking it as a class is
	the cast, inlined where it is taken.
**/
@:forward
abstract EventTarget(IEmitter) from IEmitter to IEmitter {
	@:to extern inline function toEmitter<T:IEmitter>():T {
		return cast this;
	}
}
