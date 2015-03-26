package flock;

import flock.FieldPoint.RndPoint;
import hxsignal.Signal;
import motion.easing.*;
import worker.FlockData;

import net.rezmason.utils.workers.Golem;
import net.rezmason.utils.workers.QuickBoss;

import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Tilesheet;
import openfl.geom.Rectangle;

import util.Env;
import util.MathUtil;

import worker.Data;
import worker.Data.FloatArray;
import worker.FlockData.FlockBoss;
import worker.FlockData.FlockUpdateData;


@:final class FlockTiles extends Sprite {
	
	#if debugDraw
	public var debugVisible:Bool = true;
	var debugTilesheet	:Tilesheet;
	var debugDrawList	:FloatArray;
	#end

	var inputs			:Inputs;
	var needData		:Bool = true;
    var flocker			:FlockBoss = null;
	
	var forces			:Array<FieldPoint>;
	var pointForces		:FloatArray;
	var flockUpdateData	:FlockUpdateData;
	
	var smooth			:Bool;
	var boidBitmap		:BitmapData;
	var tilesheet		:Tilesheet;
	
	var phase			:Float;
	var count			:Int;
	
	var drawList		:FloatArray;
	var drawCount		:Int;
	
	public var updated(default, null):Signal<FloatArray->Int->Void>;
	
	public function new(inputs:Inputs) {
		
		super();
		
		this.inputs = inputs;
		
		updated = new Signal<FloatArray->Int->Void>();
		smooth = false;
		
		#if android
			count = 768;
		#elseif cpp
			count = 1024;
		#else
			count = 512;
		#end
		
		drawCount = (count * FlockData.TILE_FIELDS) << 1; // * 2 for the reflection-esq clones...
		
		#if debugDraw
			var data = [-10.0, -10.0, 0, /**/-10.0, -10.0, 1, /**/-10.0, -10.0, 2, /**/-10.0, -10.0, 3, /**/-10.0, -10.0, 4, /**/-10.0, -10.0, 5];
			debugTilesheet = new Tilesheet(Assets.getBitmapData('img/rgbcmy8.png'));
			for (i in 0...3) {
				for (j in 0...2) debugTilesheet.addTileRect(new Rectangle (i*8, j*8, 8, 8));
			}
			#if js
				debugDrawList = new FloatArray(data);
			#else
				debugDrawList = data;
			#end
		#end
		
		tilesheet = new Tilesheet(boidBitmap = Assets.getBitmapData("img/blurBlob.png"));
		tilesheet.addTileRect(new Rectangle (0, 0, boidBitmap.width, boidBitmap.height));
		
		phase = (Math.random() - .5) * (Math.PI * 4);
		createWorker();
		
		inputs.enterFrame.connect(enterFrame);
	}
	
	
	function createWorker() {
		
		// radial point forces...
		var fx:Array<Float> = [
			/* x, y, force */
			-10, -10, .000005,
			-10, -10, .000005,
			-10, -10, .000005,
			//-10, -10, .0,
			//-10, -10, .0,
			640, 220, 0, /* mouse controlled */
		];
		
		forces = [
			new RndPoint(4.8, .00000001, Linear.easeNone, Std.int(Math.random()*0xffffff)),
			new RndPoint(4.6, .00000001, Linear.easeNone, Std.int(Math.random()*0xffffff)),
			new RndPoint(4.4, .00000001, Linear.easeNone, Std.int(Math.random()*0xffffff)),
			//new RndPoint(4.2, .00000001, Linear.easeNone, Std.int(Math.random()*0xffffff)),
			//new RndPoint(4,   .00000001, Linear.easeNone, Std.int(Math.random()*0xffffff)),
		];
		
		#if js
		pointForces = new FloatArray(fx);
		#else
		pointForces	= fx;
		#end
		
		// create this container now, send it with each update
		flockUpdateData = { type:Data.TYPE_UPDATE, pointForces:pointForces, scaleFactor:Env.scaleFactor };
		
		flocker = new FlockBoss(Golem.rise('assets/golem/flocking_worker.hxml'), onWorkerComplete, onWorkerError);		
		flocker.start();
		flocker.send(cast { type:Data.TYPE_INIT, count:count, screenDensity:Env.screenDensity } ); // init
	}
	
	
	function enterFrame(now:Float, dt:Float) {	
		
		if (needData) return;
		
		graphics.clear();
		tilesheet.drawTiles(graphics, cast drawList, smooth, Tilesheet.TILE_SCALE | Tilesheet.TILE_ALPHA, drawCount);
		needData = true;
		
		var f; var j;
		var n = forces.length; var pt;
		for (i in 0...n) {
			j = i * 3;
			f = forces[i];
			f.step(now, dt);
			pt = f.current;
			pointForces[j + 0] = pt.x;
			pointForces[j + 1] = pt.y;
			pointForces[j + 2] = pt.f;
		}
		
		#if debugDraw
		if (debugVisible) debugDraw();
		#end
		
		//
		var mIndx = (forces.length * 3);
		var v = inputs.mouseVelocity;
		var f = pointForces[mIndx + 2];
		#if mobile
		if (v > 0) {
		#else
		if (v > 0 && inputs.mouseIsDown) {
		#end		
			pointForces[mIndx] 		= mouseX;
			pointForces[mIndx + 1]	= mouseY;
			pointForces[mIndx + 2]	= f + (v - f) * 5e-12;
		} else {
			pointForces[mIndx + 2]	= f > 5e-12 ? f * .8 : 0;
		}
		
		updated.emit(drawList, drawCount);
		
		flockUpdateData.scaleFactor = Env.scaleFactor;
		// send the update request + data...
		flocker.send(flockUpdateData);
	}
	
	#if debugDraw
	inline function debugDraw() {
		var n = Std.int(pointForces.length / 3);
		for (i in 0...n) {
			var j = i * 3;
			debugDrawList[j] 	 = pointForces[j];
			debugDrawList[j + 1] = pointForces[j + 1];
			debugDrawList[j + 2] = pointForces[j + 2] > .0 ? 2 : 0;
		}
		debugTilesheet.drawTiles(graphics, cast debugDrawList, false);
	}
	#end
	
	
	/**
	 * flock data from worker
	 * drawList contains 0...drawCount elements for drawing the flock and the refelction, 
	 * followed by data-points about the flock
	 * @param	d
	 */
    function onWorkerComplete(d:FloatArray) {
		needData = false;
		drawList = d;
    }
	
	
    function onWorkerError(err) {
		trace('onWorkerError ${err}');
		needData = true;
	}
}


