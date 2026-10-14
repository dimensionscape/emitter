package emitter._internal;

import emitter.IEmitter;
import haxe.Constraints.Function;
import haxe.ds.StringMap;

/**
	One lane of an emitter: the listeners of each type, for events or for
	signals. Made when the lane gets its first listener, so an emitter
	nothing listens to holds none.

	**Finding a type.** Natively and on JavaScript, the types listened for
	while there have been no more than `CHAINED` at once are chained in the
	order each was first added (`first`); past that, and on the other
	targets always, they are in `map`. Walking a few links finds a type
	sooner than a map's lookup does (natively by which string it is before
	what it says), and takes less memory than a map. Elsewhere a map's
	lookup is about as cheap as one compare, and no type is chained. Never
	both: once there is a map, every type is in it.

	**Changing a list during a dispatch.** A dispatch walks the array that
	was current when it reached this emitter, without copying it. While one
	is walking (`walking` above 0), adding or removing a listener replaces
	the array instead of changing it, so the walk goes on over the array it
	started with: a listener removed during a dispatch still runs for it,
	and one added does not. Otherwise an array is changed where it is, so a
	list of n listeners costs n, not n squared, to build and to empty.

	A list is never empty: the type goes when its last listener does.
**/
@:noCompletion
final class Lane {
	/** What `add` did: nothing, the listener being there already. **/
	public static inline var IGNORED:Int = 0;

	/** What `add` and `remove` did: added or removed one, others remaining. **/
	public static inline var CHANGED:Int = 1;

	/** What `add` did: the type's first listener; what `remove` did: its last. **/
	public static inline var TRANSITION:Int = 2;

	/** What `remove` did: nothing, the listener not being there. **/
	public static inline var NOT_FOUND:Int = 0;

	#if (cpp || js)
	/**
		How many types are chained before they all go into a map: as many as
		a walk was measured to find no later than the map would, a type
		nothing listens for included (CrossByte's measurement).
	**/
	public static inline var CHAINED:Int = #if cpp 8 #else 4 #end;

	/** The first chained type, or null when none is or `map` holds them. **/
	public var first:Null<Slot>;
	#end

	/** Every type and its listeners, by type, once they are not chained. **/
	public var map:Null<StringMap<Array<Listener>>>;

	/** How many dispatches are walking one of this lane's lists now. **/
	public var walking:Int;

	/** Whether a listener added again for a type is kept again. **/
	public var keepDuplicates:Bool;

	/** On the event lane, the emitter events are dispatched for, if not the owner. **/
	public var target:Null<IEmitter>;

	public function new(target:Null<IEmitter>) {
		#if (cpp || js)
		first = null;
		#end
		map = null;
		walking = 0;
		keepDuplicates = false;
		this.target = target;
	}

	/**
		The listeners for `type` in the order they run, or null for none. The
		array is the one a dispatch walks: read it, never change it.
	**/
	public inline function listOf(type:String):Null<Array<Listener>> {
		#if (cpp || js)
		var first:Null<Slot> = this.first;
		return if (first != null) {
			sameString(first.type, type) ? first.list : listAfter(first, type);
		} else {
			mapped(type);
		}
		#else
		return mapped(type);
		#end
	}

	private inline function mapped(type:String):Null<Array<Listener>> {
		var map = this.map;
		return (map == null || type == null) ? null : map.get(type);
	}

	/**
		Adds `fn` for `type`: after the others of its priority, or with
		`prepend` before them. With `dedupe`, a function already there for
		`type` is not added again, and keeps its place.

		@return `IGNORED`, `CHANGED`, or `TRANSITION` for the type's first.
	**/
	public function add(type:String, fn:Function, priority:Int, prepend:Bool, state:Int, dedupe:Bool):Int {
		var list:Null<Array<Listener>> = listOf(type);
		if (list == null) {
			addType(type, [new Listener(fn, priority, state)]);
			return TRANSITION;
		}

		var length:Int = list.length;
		if (dedupe) {
			for (i in 0...length) {
				if (same(list[i].fn, fn)) {
					return IGNORED;
				}
			}
		}

		var at:Int = length;
		if (prepend) {
			at = 0;
			while (at < length && list[at].priority > priority) {
				at++;
			}
		} else if (list[length - 1].priority < priority) {
			// Listeners mostly share a priority, and then each goes after the
			// last: that is checked first, so adding one does not walk the
			// list to find its end.
			at = 0;
			while (at < length && list[at].priority >= priority) {
				at++;
			}
		}

		var entry:Listener = new Listener(fn, priority, state);
		if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.insert(at, entry);
			replace(type, next);
		} else if (at == length) {
			list.push(entry);
		} else {
			list.insert(at, entry);
		}
		return CHANGED;
	}

	/**
		Removes the first listener for `type` that is `fn`.

		@return `NOT_FOUND`, `CHANGED`, or `TRANSITION` for the type's last.
	**/
	public function remove(type:String, fn:Function):Int {
		var list:Null<Array<Listener>> = listOf(type);
		if (list != null) {
			for (i in 0...list.length) {
				if (same(list[i].fn, fn)) {
					return removeAt(type, list, i);
				}
			}
		}
		return NOT_FOUND;
	}

	/**
		Removes `entry` itself, found by identity rather than by its
		function: a `once` listener that has just been called.
	**/
	public function removeEntry(type:String, entry:Listener):Int {
		var list:Null<Array<Listener>> = listOf(type);
		if (list != null) {
			for (i in 0...list.length) {
				if (list[i] == entry) {
					return removeAt(type, list, i);
				}
			}
		}
		return NOT_FOUND;
	}

	/** Whether `fn` listens for `type`. **/
	public function has(type:String, fn:Function):Bool {
		var list:Null<Array<Listener>> = listOf(type);
		if (list != null) {
			for (i in 0...list.length) {
				if (same(list[i].fn, fn)) {
					return true;
				}
			}
		}
		return false;
	}

	/** Forgets `type` and its listeners; whether it had any. **/
	public function removeType(type:String):Bool {
		if (type == null) {
			return false;
		}
		var map = this.map;
		if (map != null) {
			return map.remove(type);
		}
		#if (cpp || js)
		var previous:Null<Slot> = null;
		var slot:Null<Slot> = first;
		while (slot != null) {
			if (slot.type == type) {
				if (previous == null) {
					first = slot.next;
				} else {
					previous.next = slot.next;
				}
				return true;
			}
			previous = slot;
			slot = slot.next;
		}
		#end
		return false;
	}

	/**
		Forgets every type; the ones it had, in no particular order, or null
		when it had none. Dispatches walking a list go on over it.
	**/
	public function clear():Null<Array<String>> {
		var types:Null<Array<String>> = null;
		#if (cpp || js)
		var slot:Null<Slot> = first;
		if (slot != null) {
			types = [];
			while (slot != null) {
				types.push(slot.type);
				slot = slot.next;
			}
		}
		first = null;
		#end
		var map = this.map;
		if (map != null) {
			for (type in map.keys()) {
				if (types == null) {
					types = [];
				}
				types.push(type);
			}
		}
		this.map = null;
		return types;
	}

	/** Whether `a` and `b` are one listener: see `Emitter.removeEventListener`. **/
	public static inline function same(a:Function, b:Function):Bool {
		#if (cpp || js)
		// hxcpp compares two reads of one bound method equal, and JavaScript
		// caches the binding: `==` is enough.
		return a == b;
		#else
		// On eval, neko and the jvm each read of `this.method` is a new
		// closure `==` never matches.
		return a == b || Reflect.compareMethods(a, b);
		#end
	}

	private function removeAt(type:String, list:Array<Listener>, at:Int):Int {
		if (list.length == 1) {
			removeType(type);
			return TRANSITION;
		}
		if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.splice(at, 1);
			replace(type, next);
		} else {
			list.splice(at, 1);
		}
		return CHANGED;
	}

	/** Puts `list` in place of the listeners of `type`, which has some. **/
	private function replace(type:String, list:Array<Listener>):Void {
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		#if (cpp || js)
		var slot:Null<Slot> = first;
		while (slot != null) {
			if (slot.type == type) {
				slot.list = list;
				return;
			}
			slot = slot.next;
		}
		#end
	}

	/** A type's first listeners: chained, or mapped once there are many. **/
	private function addType(type:String, list:Array<Listener>):Void {
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		#if (cpp || js)
		var last:Null<Slot> = first;
		if (last == null) {
			first = new Slot(type, list);
			return;
		}
		var count:Int = 1;
		while (last.next != null) {
			last = last.next;
			count++;
		}
		if (count < CHAINED) {
			last.next = new Slot(type, list);
			return;
		}
		// One more than the chain keeps: all of them go into a map, and stay
		// there. A lane that went past the chain once may again.
		map = new StringMap();
		var slot:Null<Slot> = first;
		while (slot != null) {
			map.set(slot.type, slot.list);
			slot = slot.next;
		}
		first = null;
		#else
		map = new StringMap();
		#end
		map.set(type, list);
		this.map = map;
	}

	#if (cpp || js)
	/**
		The listeners for `type` from the slot after `first` on, or null. An
		emitter is mostly asked about the very strings it was given, so
		natively the walk compares which string each is first, which costs
		nothing, and only then their text; on JavaScript one walk by `===`
		is as cheap.
	**/
	public function listAfter(first:Slot, type:String):Null<Array<Listener>> {
		var slot:Null<Slot> = first.next;
		while (slot != null) {
			if (sameString(slot.type, type)) {
				return slot.list;
			}
			slot = slot.next;
		}
		#if (cpp && !cppia)
		if (type == null) {
			return null;
		}
		var length:Int = type.length;
		slot = first;
		while (slot != null) {
			var other:String = slot.type;
			if (other.length == length && other == type) {
				return slot.list;
			}
			slot = slot.next;
		}
		#end
		return null;
	}

	/**
		Whether two types are the one string: natively by where their text
		is, which costs nothing where hxcpp's `==` is a call; on JavaScript
		by `===`, as cheap there.
	**/
	public static inline function sameString(a:Null<String>, b:Null<String>):Bool {
		#if (cpp && !cppia)
		return untyped __cpp__("({0}.raw_ptr() == {1}.raw_ptr())", a, b);
		#else
		return a == b;
		#end
	}
	#end
}

#if (cpp || js)
/**
	A chained type and its listeners: a lookup finds both in one object, so
	nothing can pair one type with another's listeners.
**/
@:noCompletion
final class Slot {
	public final type:String;

	/** Its listeners, in the order they run; never empty while chained. **/
	public var list:Array<Listener>;

	public var next:Null<Slot>;

	public inline function new(type:String, list:Array<Listener>) {
		this.type = type;
		this.list = list;
		this.next = null;
	}
}
#end
