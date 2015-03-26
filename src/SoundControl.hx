package;

import flock.FlockTiles;
import motion.Actuate;
import motion.actuators.PropertyDetails;
import motion.actuators.SimpleActuator;
import motion.easing.Sine;
import openfl.Assets;
import openfl.events.Event;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import util.MathUtil;
import worker.Data.FloatArray;
import worker.FlockData;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

@:final typedef SoundMap = Map<String, openfl.media.Sound>

@:final typedef ChannelMap = Map<openfl.media.Sound, openfl.media.SoundChannel>

@:final typedef Note = {
	@:optional var index:Int;
	var volume:Float;
	var when:Float;
	var pan:Float;
}

@:final typedef ScheduledNote = {> Note,
	var sound:Sound;
}


class SoundControl {
	
	static inline var MAX_POLYPHONY			:Int = 12;
	static inline var SOUND_END				:Int = 2100;
	static inline var SOUND_BEGIN			:Int = 900;
	static inline var SOUND_RANGE			:Int = SOUND_END - SOUND_BEGIN;
	static inline var MIN_RETRIGGER_DURATION:Int = Std.int(SOUND_RANGE / 2);
	static inline var MIN_RETRIGGER_POSITION:Int = SOUND_BEGIN + MIN_RETRIGGER_DURATION;
	static inline var AUDIO_TYPE			:String = 'ogg';
	// need to add mp3/aac here to support IE... but meh.

	var sounds		:SoundMap;
	var channels	:ChannelMap;
	var noteIDs		:Array<String>;
	var noteQueue	:Array<ScheduledNote>;
	var sequencer	:NoteSequencer;
	var paused		:Bool;
	var polyphony	:Int;
	
	public var now(default, null):Float;
	
	public var noteCount(get, never):Int;
	inline function get_noteCount() return noteIDs.length;

	
	public function new(inputs:Inputs, flock:FlockTiles) {
		
		flock.updated.connect(flockUpdate);
		paused = false;
		polyphony = 0;
		sequencer = new NoteSequencer(this);
		sounds = new SoundMap();
		channels = new ChannelMap();
		noteQueue = [];
		
		var notes = '';
		for (octave in 2...6) notes += 'C$octave,C_$octave,D$octave,D_$octave,E$octave,F$octave,F_$octave,G$octave,G_$octave,A$octave,A_$octave,B$octave${octave==5?"":","}';
		noteIDs = notes.split(',');
		
		for (id in noteIDs) {
			sounds.set(id, Assets.getSound('audio/notes/note_${id}.${AUDIO_TYPE}'));
		}
		
		now = inputs.now;
		inputs.enterFrame.connect(update);
	}
	
	
	function flockUpdate(data:FloatArray, offset:Int) {
		sequencer.update(data, offset, now);
	}
	
	
	function update(now:Float, dt:Float) {
		this.now = now;
		
		for (sound in channels.keys()) {
			var channel = channels.get(sound);
			if (channel.position >= SOUND_END) {
				stopChannelSound(channel, sound);
			} 
		}
		
		if (paused) return;
		
		var processed	= [];
		var i 			= noteQueue.length;
		while (i-- > 0) {
			var item = noteQueue[i];
			if (now >= item.when) {
				if (polyphony < MAX_POLYPHONY && playQueued(item)) polyphony++;
				processed.push(i);
			}
		}
		
		for (index in processed) noteQueue.splice(index, 1);
	}
	
	public function play(when:Float = 0, noteIndex:Int=0, volume:Float=1, pan:Float=0) {
		var sound = sounds.get(noteIDs[noteIndex]);
		if (sound != null) scheduleSound(when, sound, volume, pan);
	}
	
	
	public function stopAllSounds(clearQueue:Bool = true) {
		if (clearQueue) noteQueue = [];
		for (sound in channels.keys()) {
			stopChannelSound(channels.get(sound), sound);
		}
	}
	
	public function setPause(paused:Bool) {
		if (paused != this.paused) {
			this.paused = paused;
			polyphony = 0;
			noteQueue = [];
		}
	}
	
	
	inline function scheduleSound(when:Float, sound:Sound, volume:Float, pan:Float) {
		noteQueue.push({when:when, sound:sound, volume:volume, pan:pan});
	}
	
	inline function stopChannelSound(channel:SoundChannel, sound:Sound) {
		channel.stop();
		channels.remove(sound);
		if(polyphony > 0) polyphony--;
	}
	
	function playQueued(item:ScheduledNote):Bool {
		
		var s = item.sound;
		var channel;
		
		if (channels.exists(s)) {
			channel = channels.get(s);
			if (channel.position >= MIN_RETRIGGER_POSITION) { // allow retrigger, but not too soon in the playback - prematurely cut off samples sound nasty.
				stopChannelSound(channel, s);
			} else {
				return false;
			}
		}
		
		channel = s.play(SOUND_BEGIN);
		
		var t = channel.soundTransform;
		t.volume = item.volume;
		t.pan = item.pan;
		channel.soundTransform = t;
		
		channels.set(s, channel);	
		
		return true;
	}
}

@:final class NoteSequencer {
	
	var control			:SoundControl;
	var lastTime		:Float;
	
	var playTime		:Float = .0;
	var triggerTime		:Float = .25;
	var noteWeights		:FloatArray;
	var volumeWeights	:FloatArray;
	
	
	public function new(control:SoundControl) {
		this.control = control;
		lastTime = .0;
		#if cpp
		noteWeights = [for(c in 0...FlockData.Y_DATA_POINTS) .0];
		volumeWeights = [for (c in 0...FlockData.X_DATA_POINTS) .0];
		#else
		noteWeights = new FloatArray([for(c in 0...FlockData.Y_DATA_POINTS) .0]);
		volumeWeights = new FloatArray([for (c in 0...FlockData.X_DATA_POINTS) .0]);
		#end
		noteTimeUpdate();
	}
	
	var t:PositionAccessActuator;
	
	function noteTimeUpdate() {
		
		var time = .15 + .25 * Math.random();
		var duration = .25 + 180 * Math.random();
		
		t = cast Actuate.tween(this, duration, { triggerTime:time }, true, PositionAccessActuator)
			.ease(Sine.easeInOut)
			.onComplete(noteTimeUpdate);
		
		//trace('time:$time');
		//trace('triggerTime:$triggerTime');
		//trace('duration:$duration');
	}
	
	
	/**
	 * process the flock info data...
	 * @param	data
	 * @param	offset
	 * @param	now
	 */	
	public function update(data:FloatArray, offset:Int, now:Float) {
		if (lastTime == 0) lastTime = now;
		var dt 	= now - lastTime;
		lastTime = now;
		
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
			
			var play;
			var wVolume, wNote;
			for(i in 0...FlockData.X_DATA_POINTS) {
				
				wVolume	= volumeWeights[i] 	* maxVol;
				wNote 	= noteWeights[i] 	* maxNote;
				play 	= playNote(wNote, wVolume);
				
				if (play) {
					control.play(now + (triggerTime * wNote * wVolume*2), i, wVolume * triggerTime);
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
	
	
	function playNote(noteWeight, volumeWeight) {
		
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
class PositionAccessActuator extends SimpleActuator<NoteSequencer,Float> {
	
	public var position:Float = .0;	
	
	override function update(currentTime:Float):Void {
		position = (currentTime - timeOffset) / duration;
		super.update(currentTime);
	}
}