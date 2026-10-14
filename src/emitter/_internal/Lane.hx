package emitter._internal;

import emitter.IEmitter;
import haxe.Constraints.Function;
import haxe.ds.StringMap;

/**
	One lane of an emitter: the listeners of each type, for events or for
	signals. Made when the lane gets its first listener, so an emitter
	nothing listens to holds none.

	**Finding a type.** Natively, on the jvm and on JavaScript, the types
	listened for while there have been no more than `CHAINED` at once are
	chained in `Slot`s, in the order each was first added; past that they
	are in `map`. Walking a few links finds a type sooner than a map's
	lookup does (natively by which string it is before what it says), takes
	less memory than a map, and leaves a dispatch small enough for a JIT to
	inline whole. On eval, HashLink and Neko the types are always in a map.
	Never both: once there is a map, every type is in it.

	Where types are chained, the lane is the first slot itself, so finding
	the first type reads no more than finding a field; elsewhere the lane is
	the map itself, for the same reason.

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
final class Lane extends #if (cpp || js || jvm) Slot #else StringMap<Array<Listener>> #end {
	/** What `add` did: nothing, the listener being there already. **/
	public static inline var IGNORED:Int = 0;

	/** What `add` and `remove` did: added or removed one, others remaining. **/
	public static inline var CHANGED:Int = 1;

	/** What `add` did: the type's first listener; what `remove` did: its last. **/
	public static inline var TRANSITION:Int = 2;

	/** What `remove` did: nothing, the listener not being there. **/
	public static inline var NOT_FOUND:Int = 0;

	#if (cpp || js || jvm)
	/**
		How many types are chained before they all go into a map: as many as
		a walk was measured to find no later than the map would, a type
		nothing listens for included. Natively 8, where a walk compares
		which string each type is before its text, and on JavaScript 4, where
		it compares text (CrossByte's measurements); the jvm compares text as
		JavaScript does, and takes its 4.
	**/
	public static inline var CHAINED:Int = #if cpp 8 #else 4 #end;

	/** Every type and its listeners, by type, once they are not chained. **/
	public var map:Null<StringMap<Array<Listener>>>;
	#end

	/** How many dispatches are walking one of this lane's lists now. **/
	public var walking:Int;

	/** Whether a listener added again for a type is kept again. **/
	public var keepDuplicates:Bool;

	/** On the event lane, the emitter events are dispatched for, if not the owner. **/
	public var target:Null<IEmitter>;

	public function new(target:Null<IEmitter>) {
		#if (cpp || js || jvm)
		super(null, null);
		map = null;
		#else
		super();
		#end
		walking = 0;
		keepDuplicates = false;
		this.target = target;
	}

	/**
		The listeners for `type` in the order they run, or null for none. The
		array is the one a dispatch walks: read it, never change it.
	**/
	public inline function listOf(type:String):Null<Array<Listener>> {
		#if (cpp || js || jvm)
		// The first chained type is found by one compare: with none chained,
		// `this.type` is null and `this.list` too, so even a null type
		// matching it finds nothing.
		return sameString(this.type, type) ? this.list : listAfter(type);
		#else
		return mapped(type);
		#end
	}

	private inline function mapped(type:String):Null<Array<Listener>> {
		#if (cpp || js || jvm)
		var map = this.map;
		return (map == null || type == null) ? null : map.get(type);
		#else
		return type == null ? null : get(type);
		#end
	}

	/**
		Adds `fn` for `type`: after the others of its priority, or with
		`prepend` before them. With `dedupe`, a function already there for
		`type` is not added again, and keeps its place.

		Inlined where an emitter adds, so the usual add (a listener after the
		last, nothing walking) costs one call fewer; anything else is
		`insert`'s.

		@return `IGNORED`, `CHANGED`, or `TRANSITION` for the type's first.
	**/
	public inline function add(type:String, fn:Function, priority:Int, prepend:Bool, state:Int, dedupe:Bool):Int {
		var list:Null<Array<Listener>> = listOf(type);
		var result:Int = TRANSITION;
		if (list == null) {
			addType(type, [new Listener(fn, priority, state)]);
		} else if (dedupe && indexOf(list, fn) >= 0) {
			result = IGNORED;
		} else {
			var entry:Listener = new Listener(fn, priority, state);
			if (walking == 0 && !prepend && list[list.length - 1].priority >= priority) {
				list.push(entry);
			} else {
				insert(type, list, entry, prepend);
			}
			result = CHANGED;
		}
		return result;
	}

	/**
		Puts `entry` in its place among the listeners for `type`: after the
		others of its priority, or with `prepend` before them. While a
		dispatch walks the list, into a copy that replaces it.
	**/
	private function insert(type:String, list:Array<Listener>, entry:Listener, prepend:Bool):Void {
		var priority:Int = entry.priority;
		var length:Int = list.length;
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
		if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.insert(at, entry);
			replace(type, next);
		} else if (at == length) {
			list.push(entry);
		} else {
			list.insert(at, entry);
		}
	}

	/**
		Removes the first listener for `type` that is `fn`. Inlined where an
		emitter removes, as `add` is.

		@return `NOT_FOUND`, `CHANGED`, or `TRANSITION` for the type's last.
	**/
	public inline function removeListener(type:String, fn:Function):Int {
		var list:Null<Array<Listener>> = listOf(type);
		var at:Int = list == null ? -1 : indexOf(list, fn);
		return at < 0 ? NOT_FOUND : removeAt(type, list, at);
	}

	/** Where `fn` is in `list`, or -1. **/
	public static inline function indexOf(list:Array<Listener>, fn:Function):Int {
		var found:Int = -1;
		var i:Int = 0;
		var length:Int = list.length;
		while (i < length) {
			if (same(list[i].fn, fn)) {
				found = i;
				break;
			}
			i++;
		}
		return found;
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
		return list != null && indexOf(list, fn) >= 0;
	}

	/** Forgets `type` and its listeners; whether it had any. **/
	public function removeType(type:String):Bool {
		if (type == null) {
			return false;
		}
		#if !(cpp || js || jvm)
		return remove(type);
		#else
		var map = this.map;
		if (map != null) {
			return map.remove(type);
		}
		if (head() == null) {
			return false;
		}
		#if (cpp && !cppia)
		// It was most likely found by which string it is: that first.
		if (unlink(type, true)) {
			return true;
		}
		#end
		return unlink(type, false);
		#end
	}

	/**
		Forgets every type; the ones it had, in no particular order, or null
		when it had none. Dispatches walking a list go on over it.
	**/
	public function clearAll():Null<Array<String>> {
		var types:Null<Array<String>> = null;
		#if !(cpp || js || jvm)
		for (type in keys()) {
			if (types == null) {
				types = [];
			}
			types.push(type);
		}
		clear();
		#else
		var slot:Null<Slot> = head();
		while (slot != null) {
			if (types == null) {
				types = [];
			}
			types.push(slot.type);
			slot = slot.next;
		}
		dropChain();
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
		#end
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

	private inline function removeAt(type:String, list:Array<Listener>, at:Int):Int {
		var result:Int = CHANGED;
		if (list.length == 1) {
			removeType(type);
			result = TRANSITION;
		} else if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.splice(at, 1);
			replace(type, next);
		} else {
			list.splice(at, 1);
		}
		return result;
	}

	/** Puts `list` in place of the listeners of `type`, which has some. **/
	private function replace(type:String, list:Array<Listener>):Void {
		#if !(cpp || js || jvm)
		set(type, list);
		#else
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		var slot:Null<Slot> = head();
		while (slot != null) {
			if (sameString(slot.type, type) #if (cpp && !cppia) || slot.type == type #end) {
				slot.list = list;
				return;
			}
			slot = slot.next;
		}
		#end
	}

	/** A type's first listeners: chained, or mapped once there are many. **/
	private function addType(type:String, list:Array<Listener>):Void {
		#if !(cpp || js || jvm)
		set(type, list);
		#else
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		var first:Null<Slot> = head();
		if (first == null) {
			this.type = type;
			this.list = list;
			return;
		}
		var count:Int = 1;
		var last:Slot = first;
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
		dropChain();
		map.set(type, list);
		this.map = map;
		#end
	}

	#if (cpp || js || jvm)
	/** The first chained slot, or null: the lane itself, while it holds a type. **/
	private inline function head():Null<Slot> {
		return this.type == null ? null : this;
	}

	/** Forgets the whole chain. **/
	private inline function dropChain():Void {
		this.type = null;
		this.list = null;
		this.next = null;
	}

	/** Takes the chained `type` out: found by which string it is, or by its text. **/
	private function unlink(type:String, byPointer:Bool):Bool {
		var first:Null<Slot> = head();
		if (first == null) {
			return false;
		}
		if (matches(first.type, type, byPointer)) {
			// The lane is the first slot: the second moves into it.
			var second:Null<Slot> = next;
			if (second == null) {
				this.type = null;
				this.list = null;
			} else {
				this.type = second.type;
				this.list = second.list;
				this.next = second.next;
			}
			return true;
		}
		var previous:Slot = first;
		var slot:Null<Slot> = first.next;
		while (slot != null) {
			if (matches(slot.type, type, byPointer)) {
				previous.next = slot.next;
				return true;
			}
			previous = slot;
			slot = slot.next;
		}
		return false;
	}

	private static inline function matches(a:Null<String>, b:String, byPointer:Bool):Bool {
		#if (cpp && !cppia)
		return byPointer ? sameString(a, b) : a == b;
		#else
		return sameString(a, b);
		#end
	}

	/**
		The listeners for `type`, known not to be the first chained one by
		which string it is, or null; with nothing chained, from the map. An
		emitter is mostly asked about the very strings it was given, so
		natively the walk compares which string each is first, which costs
		nothing, and only then their text; on JavaScript one walk by `===`
		is as cheap.
	**/
	public function listAfter(type:String):Null<Array<Listener>> {
		if (this.type == null) {
			return mapped(type);
		}
		var first:Slot = this;
		var slot:Null<Slot> = next;
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
		by `==`, as cheap there. On the jvm `==` between two strings is
		`compareTo`, which reads every character even of the very same
		string: `equals` looks at identity first, and a string keeps its
		hash, so two that differ are told apart by it at once.
	**/
	public static inline function sameString(a:Null<String>, b:Null<String>):Bool {
		#if (cpp && !cppia)
		return untyped __cpp__("({0}.raw_ptr() == {1}.raw_ptr())", a, b);
		#elseif jvm
		return if (a == null || b == null) {
			a == null && b == null;
		} else {
			var text:java.NativeString = cast a;
			text.hashCode() == (cast b : java.NativeString).hashCode() && text.equals(b);
		}
		#else
		return a == b;
		#end
	}
	#end
}

#if (cpp || js || jvm)
/**
	A chained type and its listeners: a lookup finds both in one object, so
	nothing can pair one type with another's listeners. The lane is its own
	first slot, and takes the second's type when the first goes.
**/
@:noCompletion
class Slot {
	public var type:Null<String>;

	/** Its listeners, in the order they run; never empty while chained. **/
	public var list:Null<Array<Listener>>;

	public var next:Null<Slot>;

	public function new(type:Null<String>, list:Null<Array<Listener>>) {
		this.type = type;
		this.list = list;
		this.next = null;
	}
}
#end
