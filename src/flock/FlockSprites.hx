package flock;

import flock.FieldPoint.RndPoint;
import flock.worker.*;
import flock.worker.types.*;
import flock.worker.types.FlockControl;
import flock.worker.types.FlockUpdateData;
import flock.worker.types.WorkerDataType;
import js.html.Float32Array;
import motion.easing.*;
import net.rezmason.utils.workers.Golem;
import pixi.core.particles.ParticleContainer;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import util.Inputs;


class FlockSprites extends ParticleContainer {
	
	static public inline var BoidCount:Int = 620;
	static public inline var SpriteCount:Int = BoidCount << 1; // x2 for th 'reflection' clones
	static public inline var DataSize:Int = SpriteCount * FlockDataFields.COUNT;
	
	var needData		:Bool = true;
    var flocker			:FlockControl = null;
	
	var forces			:Array<FieldPoint>;
	var pointForces		:Float32Array;
	var flockUpdateData	:FlockUpdateData;
	
	var drawDataCount	:Int;
	var inputs			:Inputs;
	
	public var drawList(default,null):Float32Array;
	
	public function new(inputs:util.Inputs) {
		
		super(SpriteCount, {scale:true, position:true, alpha:true});
		
		this.inputs = inputs;
		
		var texture = Texture.fromImage("img/blurBlob.png");
		for (i in 0...SpriteCount) {
			var s = new Sprite(texture);
			s.x = -100;
			addChild(s);
		}
		
		createWorker();
	}
	
	
	function createWorker() {
		
		// radial point forces...
		var fx:Array<Float> = [
			/* x, y, force */
			-10, -10, 1,
			-10, -10, 1,
			-10, -10, 1,
		];
		
		forces = [
			new RndPoint(6, .1, Linear.easeNone, Std.int(Math.random() * 0x7fffffff)),
			new RndPoint(7, .1, Linear.easeNone, Std.int(Math.random() * 0x7fffffff)),
			new RndPoint(8, .1, Linear.easeNone, Std.int(Math.random() * 0x7fffffff)),
		];
		
		pointForces = new Float32Array(fx);
		
		// create this container now, send it with each update
		flockUpdateData = { type:WorkerDataType.UPDATE, pointForces:pointForces, drawScale:1.0 };
		
		flocker = new FlockControl(Golem.rise('res/flocking_worker.hxml'), onWorkerComplete, onWorkerError);		
		flocker.start();
		flocker.send(cast { type:WorkerDataType.INIT, count:BoidCount } ); // init
	}
	
	
	/**
	 * @param	now seconds
	 * @param	dt seconds
	 */
	public function update(now:Float, dt:Float, scale:Float=1.0):Bool {	
		
		if (needData) return false;
		
		var j = 0;
		var i = 0;
		var child;
		while (i < DataSize) {
			
			child = getChildAt(j);
			child.x = drawList[i + FlockDataFields.DATA_X];
			child.y = drawList[i + FlockDataFields.DATA_Y];
			child.scale.set(drawList[i + FlockDataFields.DATA_SCALE]);
			child.alpha = drawList[i + FlockDataFields.DATA_ALPHA];
			
			i += FlockDataFields.COUNT;
			j++;
		}
		
		var f; var j; var pt;
		var n = forces.length;
		for (i in 0...n) {
			j = i * 3;
			f = forces[i];
			f.step(now, dt);
			pt = f.current;
			pointForces[j + 0] = pt.x;
			pointForces[j + 1] = pt.y;
			pointForces[j + 2] = pt.f;
		}
		
		// send the update request
		flockUpdateData.drawScale = scale;
		flocker.send(flockUpdateData);
		return true;
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


