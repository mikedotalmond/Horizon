package flock;

import flock.FlockSprites;
import js.html.Float32Array;
import motion.Actuate;

import motion.actuators.PropertyDetails;
import motion.actuators.SimpleActuator;
import motion.easing.Sine;

import util.MathUtil;
import worker.FlockData;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

class SoundControl {
	
	static inline var MAX_POLYPHONY			:Int = 12;
	static inline var SOUND_END				:Int = 2100;
	static inline var SOUND_BEGIN			:Int = 900;
	static inline var SOUND_RANGE			:Int = SOUND_END - SOUND_BEGIN;
	static inline var MIN_RETRIGGER_DURATION:Int = Std.int(SOUND_RANGE / 2);
	static inline var MIN_RETRIGGER_POSITION:Int = SOUND_BEGIN + MIN_RETRIGGER_DURATION;
	static inline var AUDIO_TYPE			:String = 'ogg';
	// need to add mp3/aac here to support IE... but meh.

	var noteIDs		:Array<String>;
	
	var playTime		:Float = .0;
	var triggerTime		:Float = .25;
	var noteWeights		:Float32Array;
	var volumeWeights	:Float32Array;
	
	
	public function new(flock:FlockSprites) {
		
		noteWeights = new Float32Array([for(c in 0...FlockData.Y_DATA_POINTS) .0]);
		volumeWeights = new Float32Array([for (c in 0...FlockData.X_DATA_POINTS) .0]);
		
		var notes = '';
		for (octave in 2...6) notes += 'C$octave,C_$octave,D$octave,D_$octave,E$octave,F$octave,F_$octave,G$octave,G_$octave,A$octave,A_$octave,B$octave${octave==5?"":","}';
		noteIDs = notes.split(',');
		
		for (id in noteIDs) {
			//sounds.set(id, Assets.getSound('audio/notes/note_${id}.${AUDIO_TYPE}'));
		}
		
		noteTimeUpdate();
	}
	
	public function play(noteIndex:Int=0, delay:Float = 0, volume:Float=1) {
		//
		//trace(noteIndex, delay, volume);
	}
	
	/**
	 * process the flock info data...
	 * @param	data
	 * @param	offset
	 * @param	now
	 */	
	public function update(dt:Float, data:Float32Array, offset:Int) {
		
		playTime += dt;
		
		if (playTime >= triggerTime * (Math.random() * .1 + .9)) {
			playTime = 0;
			
			var w;
			var maxVol = .0;
			var maxNote = .0; 
			
			for(i in 0...FlockData.X_DATA_POINTS) {
				w 		= volumeWeights[i];
				maxVol 	= MathUtil.max(maxVol, w);				
				w 		= noteWeights[i];
				maxNote	= MathUtil.max(maxNote, w);
			}
			
			maxVol = 1 / maxVol;
			maxNote = 1 / maxNote;
			
			var shouldPlay;
			var wVolume, wNote;
			for(i in 0...FlockData.X_DATA_POINTS) {
				
				wVolume	= volumeWeights[i] * maxVol;
				wNote = noteWeights[i] * maxNote;
				shouldPlay = shouldPlayNote(wNote, wVolume);
				
				if (shouldPlay) {
					play(i, triggerTime * wNote * wVolume * 2, wVolume * triggerTime);
					volumeWeights[i] = noteWeights[i] = .0;
				} else {
					volumeWeights[i] *= .666;
					noteWeights[i] *= .666;
				}
			}
		}
		
		var n = data.length;
		var i = offset; 
		var j = 0;
		
		while (i < n) {
			if (j < FlockData.X_DATA_POINTS) {
				volumeWeights[j] += data[i];
			} else {
				noteWeights[j - FlockData.X_DATA_POINTS] += data[i];
			}
			i++; j++;
		}
	}
	
	var t:PositionAccessActuator;
	function noteTimeUpdate() {
		
		var time = .15 + .25 * Math.random();
		var duration = .25 + 180 * Math.random();
		
		t = cast Actuate
			.tween(this, duration, { triggerTime:time }, true, PositionAccessActuator)
			.ease(Sine.easeInOut)
			.onComplete(noteTimeUpdate);
	}
	
	
	function shouldPlayNote(noteWeight, volumeWeight) {
		if (volumeWeight > .0) {
			var p2 = t.position;
			p2 *= p2;
			if (Math.random() > p2) {
				return (noteWeight < .4 && noteWeight > .3) || (volumeWeight > .25 && volumeWeight < .3);
			} else if (Math.random() > p2) {
				return (noteWeight > .7 || noteWeight < .3) && (volumeWeight > .05 && volumeWeight < .55);
			}
		}
		return false;
	}
}


/**
 * Can't read position of a SimpleActuator tween by default... meh.
 */
@:final
class PositionAccessActuator extends SimpleActuator<SoundControl,Float> {
	
	public var position:Float = .0;	
	
	override function update(currentTime:Float):Void {
		position = (currentTime - timeOffset) / duration;
		super.update(currentTime);
	}
}