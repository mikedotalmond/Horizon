package sound;

import haxe.xml.Check.Attrib;
import hxsignal.Signal;
import js.Error;
import js.html.ArrayBuffer;
import js.html.audio.AudioBuffer;
import js.html.audio.AudioBufferSourceNode;
import js.html.audio.AudioContext;
import js.html.audio.AudioNode;
import js.html.audio.GainNode;
import tones.AudioBase;
import tones.Samples;

class SeascapeAudio {
	
	public static var regions(default, never):Array<AudioRegion> = SeascapeRegions.parse('res/seascape_regions.csv');
	
	public var isReady(default, null):Bool;
	public var isDecoding(default, null):Bool;
	public var ready(default, null):Signal<Void->Void>;
	public var error(default, null):Signal<String->Void>;
	public var loadProgress(default, null):Signal<Float->Void>;
	public var bufferLoaded(default, null):Signal<Void->Void>;
	
	public var outGain(default,null):GainNode;
	public var muted(default,null):Bool=false;
	
	var context:AudioContext;
	var arrayBuffer:ArrayBuffer;
	var samples:Samples;
	var activeRegions:Map<Int, Int>;
	
	public function new() {
		
		isReady = false;
		
		context = AudioBase.createContext();
		
		outGain = context.createGain();
		outGain.gain.setValueAtTime(.5, context.currentTime);
		outGain.connect(context.destination);
		
		samples = new Samples(context, outGain);
		
		samples.itemRelease.connect(onItemRelease);
		activeRegions = new Map<Int,Int>();
		
		ready = new Signal<Void->Void>();
		error = new Signal<String->Void>();
		loadProgress = new Signal<Float->Void>();
		bufferLoaded = new Signal<Void->Void>();
	}
	
	public function loadBuffer() {
		
		var audioType =
			if (Samples.canPlayType('audio/ogg')) 'ogg'
			else if (Samples.canPlayType('audio/mp3')) 'mp3'
			else null;
		
		if (audioType == null) {
			error.emit('Browser does not supoprt ogg or mp3 audio playback :\\');
			return;
		}
		
		var audioURL = 'audio/seascape.$audioType';
		
		#if debug
		trace('SeascapeAudio - audioType:$audioType, audioURL:$audioURL', regions);
		#end
		
		Samples.loadArrayBuffer(audioURL, onArrayBufferLoaded, loadProgress.emit, onError);
	}
	
	
	public function decodeBuffer() {
		isDecoding = true;
		// decode blocks execution, so do this when it won't be noticed.
		Samples.decodeArrayBuffer(arrayBuffer, context, onDecoded, onError);
	}
	
	public function start() {
		
		var i = Std.int(Math.random() * regions.length);
		var region = regions[i];
		
		var maxTime = (region.duration / 2);
		var attack = maxTime * (1/3) + Math.random() * maxTime * (1/3);
		var release = maxTime * (1/3) + Math.random() * maxTime * (1/3);
		
		playRegion(i, 0.15 + Math.random() * .05, attack, release, 0);
	}
	
	public function toggleMute() {
		muted = !muted;
		outGain.gain.cancelScheduledValues(context.currentTime);
		outGain.gain.setValueAtTime(muted ? 1 / 3 : 0, context.currentTime);
		outGain.gain.linearRampToValueAtTime(muted ? 0 : 1 / 3, context.currentTime + .25);
	}
	
	
	function playRegion(index:Int, volume:Float, attack:Float, release:Float, delayBy:Float):Int {
		
		var region = regions[index];
		
		#if debug
		trace('playRegion:$index (${region.start},${region.duration}), volume:$volume, attack:$attack, release:$release, delay:$delayBy');
		#end
		
		samples.volume = volume;
		samples.attack = attack;
		samples.release = release;
		samples.offset = region.start;
		samples.duration = region.duration;
		
		var id = samples.playSample(null, delayBy);
		activeRegions.set(id, index);
		
		return id;
	}
	
	
	function onItemRelease(id:Int, time:Float) {
		
		// pick a new region to play as the last one fades out
		var lastItem = samples.activeItems.get(id);
		var lastRegion = regions[activeRegions.get(id)];
		activeRegions.remove(id);
		
		var i = Std.int(Math.random() * regions.length);
		var region = regions[i];
		
		var maxTime = (region.duration / 2);
		var attack = Math.min(lastItem.release, maxTime);
		var release = maxTime * (1/3) + Math.random() * maxTime * (1/3);
		
		playRegion(i, 0.15 + Math.random() * .05, attack, release, time - context.currentTime);
	}
	
	
	function onArrayBufferLoaded(buffer:ArrayBuffer) {
		arrayBuffer = buffer;
		bufferLoaded.emit();
	}
	
	
	function onDecoded(buffer:AudioBuffer) {
		isDecoding = false;
		samples.buffer = buffer;
		arrayBuffer = null;
		isReady = true;
		ready.emit();
	}
	
	
	function onError(err:Error) {
		trace('Error loading the AudioBuffer :(');
		trace(err);
		isReady = false;
		error.emit(err.message);
	}
}


