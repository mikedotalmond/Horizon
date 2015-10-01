package ui;

#if cpp
import worker.BackgroundImageWorker; 
#end

#if js
import js.html.CanvasRenderingContext2D;
import js.html.ImageData;
#end

import hxsignal.Signal;
import motion.Actuate;
import motion.easing.IEasing;
import motion.easing.Quad.QuadEaseIn;
import net.rezmason.utils.workers.Golem;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import openfl.utils.Int32Array;
import worker.BackgroundImageData;
import worker.BackgroundImageData.BackgroundBoss;
import worker.Data;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

@:final class BackgroundImage {
	
	public var ready(default, null):Signal<Void->Void>;
	
	var main:Main;
	public var container(default, null):DisplayObjectContainer;

	var bitmapIndex	:Int;
	var bitmaps		:Array<Bitmap>;
	var bitmapDatas	:Array<BitmapData>;
	
	var stripWidth	:Float;
	var sliceCount	:Int;
	
	var rect		:Rectangle; 
	var bgList		:Array<Int32Array>;
	
	var worker		:BackgroundBoss = null;
	var sliceData	:BackgroundStripUpdateData;
	var updateData	:BackgroundUpdateData;
	var tweenProps	:Dynamic;
	var tweenEase	:IEasing;
	var sliceRect	:Rectangle;
	var nextI		:Int;
	
	
	var needSlice	:Bool;
	var needDraw	:Bool;
	var drawComplete:Bool = false;
	var firstDraw	:Bool = true;
	
	#if js
	var ctx			:CanvasRenderingContext2D = null;
	var imgData		:ImageData = null;
	#else
	var imgBytes	:ByteArray;
	#end
	
	var nextTarget(get, never):Bitmap;
	var currentTarget(get, never):Bitmap;
	var nextTargetData(get, never):BitmapData;
	
	inline function get_currentTarget() 	return bitmaps[bitmapIndex];
	inline function get_nextTarget() 		return bitmaps[((bitmapIndex == 1) ? 0 : 1)];
	inline function get_nextTargetData()	return bitmapDatas[((bitmapIndex == 1) ? 0 : 1)];
	
	inline function gotoNextTarget() bitmapIndex = (bitmapIndex == 1) ? 0 : 1;
	
	
	public function new(main:Main) {
		this.main = main;
		
		container = new Sprite();
		main.addChild(container);
		
		ready = new Signal<Void->Void>();
		
		setupDisplayBitmaps();
	}
	
	public function setup() {
		
		
		#if js
		ctx = untyped nextTargetData.image.buffer.__srcContext;
		imgData = ctx.createImageData(BackgroundImageData.Width, 1);
		#else
		imgBytes = new ByteArray();
		#end
		
		setupAssets();
		
		// For some reason the Golem.rise fails on cpp targets when more than one worker is being used in an app... doesn't include the BackgroundImageWorker class (dce perhaps?) ??
		// This works around that problem by specificly passing the Class and not relying on Golem.rise		
		#if cpp
		worker = new BackgroundBoss(BackgroundImageWorker, onWorkerComplete, onWorkerError);
		#else
		worker = new BackgroundBoss(Golem.rise('assets/golem/background_worker.hxml'), onWorkerComplete, onWorkerError);		
		#end
		
		sliceRect 	= new Rectangle(0, 0, 1280, 1);
		sliceData 	= { type:BackgroundImageData.TYPE_STRIP_UPDATE, yIndex:0, y:getSliceY(0) };	
		updateData	= { type:Data.TYPE_UPDATE, seed:1, index:0 };
		tweenProps 	= { alpha:1 };
		tweenEase 	= new QuadEaseIn();
		
		needDraw = needSlice = drawComplete = false;
		main.inputs.enterFrame.connect(nextSlice);
		
		worker.start();
		worker.send( cast { type:Data.TYPE_INIT, sources:bgList } );
	}
	
	
	/*
	 * @param	data
	 */
	function onWorkerComplete(data:Int32Array) {
		if (data.length == 1) {
			if (data[0] == 0) {				
				ready.emit(); // 1st response after worker init completes
			} else {
				needSlice = true;
				sliceData.y = getSliceY(sliceData.yIndex = 0);
			}
		} else {
			handleSliceData(data);
		}
	}
	
	
	function handleSliceData(data:Int32Array) {
		
		// lime appears to create a new image at the full size of the canvas, then sync it all for every setPixels call...
		// it does not obey the dirty-rect, and there's some GC overhead...
		// so here we're hacking around with the internal canvas2d representation for the js target...
		// directly setting imgData here then, to draw it, we only need to call ctx.putImageData(imgData, 0, sliceRect.y);
		#if js
		var colour;
		var i = 0;
		var n = data.length;
		for (j in 0...n) {
			colour 				= data[j];
			imgData.data[i]		= (colour >> 24) & 0xff; // r
			imgData.data[i + 1] = (colour >> 16) & 0xff; // g 
			imgData.data[i + 2] = (colour >> 8) & 0xff; // b 
			imgData.data[i + 3] = 0xff; // a
			i += 4;
		}
		#else
		imgBytes.position = 0;
		for (colour in data) imgBytes.writeUnsignedInt(colour);
		imgBytes.position = 0;
		#end
		
		needDraw = true;
		if (sliceData.yIndex + 1 < BackgroundImageData.Height) needSlice = true;
		else drawComplete = true;		
		
		// get ready for next draw and slice request
		sliceData.y = getSliceY(sliceData.yIndex++);
	}
	
	/**
	 * Driven by enterFrame
	 * Run pending slice-draw requests or worker slice requests
	 * @param	now
	 * @param	dt
	 */
	function nextSlice(now, dt) {
		if (dt > (1 / 50)) return;
		
		if (needDraw) {
			needDraw = false;
			nextTargetData.lock();
			#if js			
			untyped nextTargetData.image.buffer.__srcContext.putImageData(imgData, 0, sliceRect.y);
			#else
			nextTargetData.setPixels(sliceRect, imgBytes);
			#end
			nextTargetData.unlock();
		}
		
		if (needSlice) {
			needSlice = false;
			sliceRect.y = sliceData.y;
			worker.send(cast sliceData);
			
		} else if (drawComplete) {
			drawComplete = false;
			
			var next = nextTarget;
			var current = currentTarget;
			
			next.visible = true;
			next.alpha = firstDraw ? 1 : 0;
			current.parent.setChildIndex(current, 0); // send to bottom
			firstDraw = false;
			
			var tweenTime;
			if (Math.random() > .8) {
				tweenTime = 80 - Math.random() * 40;
				nextI = Std.int(Math.random() * 4);
			} else {
				tweenTime = 40 - Math.random() * 20;
				nextI = updateData.index;
			}
			
			Actuate.tween(next, tweenTime, tweenProps)
				.onComplete(tweenInComplete)
				.ease(tweenEase);
		}
	}
	
	function tweenInComplete() {
		currentTarget.visible = false;
		gotoNextTarget();
		update(nextI, Std.int(Math.random() * 0xffffff));
	}
	
	function onWorkerError(err:Dynamic) {
		trace('bg worker error');
		throw(err);
	}
	
	
	/**
	 * needs more descriptive name
	 * @param	index Source image index (currently 0-3)
	 * @param	seed Seed for the rnd functions
	 */
	public function update(index:UInt=0, seed:UInt=1) {
		updateData.seed = seed < 1 ? 1  :seed;
		updateData.index = index;
		worker.send(cast updateData);
	}
	
	
	/**
	 * Similar to update - but no change to the source bitmap, redraw a new version from the same source
	 * @param	seed
	 */
	inline public function updateCurrent(seed:UInt=1) {
		update(updateData.index, seed);
	}
	
	
	/**
	 * 
	 */
	function setupAssets():Void {
		
		var bd1 = Assets.getBitmapData('img/horizon-bg1.jpg');
		var bd2 = Assets.getBitmapData('img/horizon-bg2.jpg');
		var bd3 = Assets.getBitmapData('img/horizon-bg3.jpg');
		var bd4 = Assets.getBitmapData('img/horizon-bg4.jpg');
		bd1.lock(); bd2.lock(); bd3.lock(); bd4.lock();
		
		var px1	= bd1.getPixels(rect);
		var px2	= bd2.getPixels(rect);
		var px3	= bd3.getPixels(rect);
		var px4	= bd4.getPixels(rect);
		
		px1.position = px2.position = px3.position = px4.position = 0;
		
		var v1 = []; var v2 = [];
		var v3 = []; var v4 = [];
		var n = px1.length >> 2;
		
		for (i in 0...n) {
			v1[i] = px1.readUnsignedInt();
			v2[i] = px2.readUnsignedInt();
			v3[i] = px3.readUnsignedInt();
			v4[i] = px4.readUnsignedInt();
		}
		
		bgList = [	
			new Int32Array(v1),
			new Int32Array(v2), 
			new Int32Array(v3), 
			new Int32Array(v4)
		];
	}
	
	
	function setupDisplayBitmaps():Void {
		
		bitmapIndex	= 0;
		bitmaps 	= [];
		bitmapDatas = [];
		
		for (i in 0...2) {
			var bd 			= new BitmapData(BackgroundImageData.Width, BackgroundImageData.Height, false, 0x0a0a0a);
			var b			= new Bitmap(bd);			
			
			rect			= bd.rect;
			b.width 		= BackgroundImageData.Width;
			
			bitmapDatas[i] 	= bd;
			bitmaps[i] 		= b;
			container.addChild(b);
		}
	}
	
	static var sliceIndices:Array<Int> = buildSliceIndices();
	
	static function buildSliceIndices():Array<Int> {
		var out 	= [];
		var upStart  = 500;
		var downStart = upStart + 1;
		var j;
		for (i in 0...BackgroundImageData.Height) {
			j = i % 3;
			if(j == 1 && downStart < BackgroundImageData.Height) out[i] = downStart++;
			else out[i] = upStart--;
		}
		return out;
	}
	
	static inline function getSliceY(yIndex:Int):Int {
		return sliceIndices[yIndex];
	}
}