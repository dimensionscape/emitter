package;

/**
	Bytes allocated per operation, natively and on the jvm: the method of
	CrossByte's allocation budgets, so the figures compare with them.

	**On the jvm** the measuring thread's own count,
	`com.sun.management.ThreadMXBean.getThreadAllocatedBytes`, read before
	and after a run, less what one reading costs.

	**Natively** hxcpp keeps no running total a reading can trust: a thread
	takes free blocks on its fast path without counting them. What does move
	with every allocation is the thread's own cursor, carried forward by each
	object's size, header and alignment. So with collection off the cursor
	is read after each operation; an operation that started and ended in the
	same hole allocated exactly the distance it moved. Those that crossed
	into another hole are left out, and the rest averaged: one operation
	allocates the same as the next. Objects of 4,000 bytes or more are
	allocated apart and counted by the collector exactly; none is expected
	here.
**/
class AllocationMeter {
	/** The median over `rounds` runs of `count` operations, in bytes per operation. **/
	public static function measure(op:Void->Void, count:Int, rounds:Int = 3):Float {
		var samples:Array<Float> = [];
		for (_ in 0...rounds) {
			samples.push(run(op, count));
		}
		samples.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		return samples[samples.length >> 1];
	}

	static function run(op:Void->Void, count:Int):Float {
		#if cpp
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.enable(false);
		var small:Float = 0.0;
		var counted:Int = 0;
		var large:Float = 0.0;
		try {
			var largeBefore:Float = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_LARGE);
			var block:Float = blockOf();
			var end:Float = holeEnd();
			var at:Float = cursor();
			for (_ in 0...count) {
				op();
				var nowBlock:Float = blockOf();
				var nowEnd:Float = holeEnd();
				var nowAt:Float = cursor();
				if (nowBlock == block && nowEnd == end && nowAt >= at) {
					small += nowAt - at;
					counted++;
				}
				block = nowBlock;
				end = nowEnd;
				at = nowAt;
			}
			large = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_LARGE) - largeBefore;
		} catch (error:Dynamic) {
			cpp.vm.Gc.enable(true);
			throw error;
		}
		cpp.vm.Gc.enable(true);
		if (counted < 50) {
			throw "only " + counted + " of " + count + " operations stayed within one hole";
		}
		return small / counted + large / count;
		#elseif jvm
		var bean:AllocatingThreadBean = cast java.lang.management.ManagementFactory.getThreadMXBean();
		var self:haxe.Int64 = java.lang.Thread.currentThread().getId();
		var cost:Float = long(bean.getThreadAllocatedBytes(self));
		cost = long(bean.getThreadAllocatedBytes(self)) - cost;
		var before:Float = long(bean.getThreadAllocatedBytes(self));
		for (_ in 0...count) {
			op();
		}
		var after:Float = long(bean.getThreadAllocatedBytes(self));
		return (after - before - cost) / count;
		#else
		return 0.0;
		#end
	}

	#if cpp
	static inline function blockOf():Float {
		return untyped __cpp__("(double)(size_t)(HX_CTX_GET->allocBase)");
	}

	static inline function holeEnd():Float {
		return untyped __cpp__("(double)(HX_CTX_GET->spaceEnd)");
	}

	static inline function cursor():Float {
		return untyped __cpp__("(double)(HX_CTX_GET->spaceStart)");
	}
	#end

	#if jvm
	static inline function long(value:haxe.Int64):Float {
		var low:Float = value.low;
		if (low < 0) {
			low += 4294967296.0;
		}
		return value.high * 4294967296.0 + low;
	}
	#end
}

#if jvm
@:native("com.sun.management.ThreadMXBean")
private extern interface AllocatingThreadBean {
	overload function getThreadAllocatedBytes(id:haxe.Int64):haxe.Int64;
}
#end
