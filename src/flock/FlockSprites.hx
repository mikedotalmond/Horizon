package flock;

import flock.FieldPoint.RndPoint;
import hxsignal.Signal;
import js.html.Float32Array;
import motion.easing.*;
import pixi.core.particles.ParticleContainer;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import worker.FlockData;

import net.rezmason.utils.workers.Golem;
import net.rezmason.utils.workers.QuickBoss;

import util.MathUtil;

import worker.Data;
import worker.FlockData.FlockBoss;
import worker.FlockData.FlockUpdateData;


class FlockSprites extends ParticleContainer {
	
	var needData		:Bool = true;
    var flocker			:FlockBoss = null;
	
	var forces			:Array<FieldPoint>;
	var pointForces		:Float32Array;
	var flockUpdateData	:FlockUpdateData;
	
	var phase			:Float;
	var count			:Int;
	
	var drawList		:Float32Array;
	var drawCount		:Int;
	
	public var updated(default, null):Signal<Float32Array->Int->Void>;
	
	public function new() {
		
		count = 512;
		drawCount = (count * FlockData.TILE_FIELDS) << 1; // * 2 for the reflection-esq clones...
	
		super(drawCount, {scale:true, position:true, alpha:true});
		
		updated = new Signal<Float32Array->Int->Void>();
		
		var texture = Texture.fromImage("img/blurBlob.png");
		for (i in 0...drawCount) {
			var s = new Sprite(texture);
			addChild(s);
		}
		
		phase = (Math.random() - .5) * (Math.PI * 4);
		createWorker();
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
		
		pointForces = new Float32Array(fx);
		
		// create this container now, send it with each update
		flockUpdateData = { type:Data.TYPE_UPDATE, pointForces:pointForces, scaleFactor:1 };
		
		flocker = new FlockBoss(Golem.rise('res/flocking_worker.hxml'), onWorkerComplete, onWorkerError);		
		flocker.start();
		flocker.send(cast { type:Data.TYPE_INIT, count:count, screenDensity:1 } ); // init
	}
	
	
	public function update(now:Float, dt:Float) {	
		
		if (needData) return;
		
		var j = 0;
		var child;
		var i = 0;
		while (i < drawCount) {
			child = getChildAt(j);
			child.x = drawList[i];
			child.y = drawList[i + 1];
			child.scale.set(drawList[i + 2]);
			child.alpha = drawList[i + 3];
			i += 4;
			j++;
		}
		
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
		
		//
		var mIndx = (forces.length * 3);
		//var v = inputs.mouseVelocity;
		var f = pointForces[mIndx + 2];
		//if (v > 0 && inputs.mouseIsDown) {
			//pointForces[mIndx] 		= mouseX;
			//pointForces[mIndx + 1]	= mouseY;
			//pointForces[mIndx + 2]	= f + (v - f) * 5e-12;
		//} else {
			pointForces[mIndx + 2]	= f > 5e-12 ? f * .8 : 0;
		//}
		
		updated.emit(drawList, drawCount);
		
		flockUpdateData.scaleFactor = 1;// Env.scaleFactor;
		
		// send the update request + data...
		flocker.send(flockUpdateData);
	}
	
	
	/**
	 * flock data from worker
	 * drawList contains 0...drawCount elements for drawing the flock and the refelction, 
	 * followed by data-points about the flock
	 * @param	d
	 */
    function onWorkerComplete(d:Float32Array) {
		needData = false;
		drawList = d;
    }
	
	
    function onWorkerError(err) {
		trace('onWorkerError ${err}');
		needData = true;
	}
}


