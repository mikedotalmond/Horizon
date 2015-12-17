package sound;

import haxe.xml.Check.Attrib;
import hxsignal.Signal;
import js.Error;
import js.html.ArrayBuffer;
import js.html.audio.AudioBuffer;
import js.html.audio.AudioBufferSourceNode;
import js.html.audio.AudioContext;
import js.html.audio.AudioNode;
import tones.AudioBase;
import tones.Samples;

class SeascapeAudio {
	
	public static var regions(default, never):Array<AudioRegion> = SeascapeRegions.parse('res/seascape_regions.csv');
	
	public var isReady(default, null):Bool;
	public var ready(default, null):Signal<Void->Void>;
	public var error(default, null):Signal<String->Void>;
	public var loadProgress(default, null):Signal<Float->Void>;
	public var bufferLoaded(default, null):Signal<Void->Void>;
	
	var context:AudioContext;
	var arrayBuffer:ArrayBuffer;
	var samples:Samples;
	var activeRegions:Map<Int, Int>;
	
	public function new() {
		
		isReady = false;
		
		context = AudioBase.createContext();
		samples = new Samples(context);
		samples.itemBegin.connect(onItemBegin);
		samples.itemRelease.connect(onItemRelease);
		samples.itemEnd.connect(onItemEnd);
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

		// region start points tend to be a little bit off after encoding - account for that here.
		// note: if using lossless (.wav) then no offset should be needed. 
		//if (audioType == 'ogg') {
			//regionOffset = 0;
		//} else {
			//regionOffset = 0;
		//}
			
		var audioURL = 'audio/seascape.$audioType';
		
		#if debug
		trace('SeascapeAudio - audioType:$audioType, audioURL:$audioURL', regions);
		#end
		
		Samples.loadArrayBuffer(audioURL, onArrayBufferLoaded, onLoadProgress, onError);
	}
	
	
	public function decodeBuffer() {
		trace('decodeBuffer');
		// decode blocks execution, so do this when it won't be noticed.
		Samples.decodeArrayBuffer(arrayBuffer, context, onDecoded, onError);
	}
	
	
	function onItemBegin(id:Int, time:Float) {
		trace('onItemBegin $id');
		
	}
	
	function onItemRelease(id:Int, time:Float) {
		trace('onItemRelease $id');
		
		// pick a new region to play
		var lastItem = samples.activeItems.get(id);
		var lastRegion = regions[activeRegions.get(id)];
		activeRegions.remove(id);
		
		var i = Std.int(Math.random() * regions.length);
		var region = regions[i];
		
		var maxTime = (region.duration / 2);
		var attack = Math.min(lastItem.release, maxTime);
		var release = maxTime * .25 + Math.random() * maxTime * .25;
		
		playRegion(i, 0.1 + Math.random()*.1, attack, release, time - context.currentTime);
	}
	
	function onItemEnd(id:Int) {
		//activeRegions.remove(id);
		trace('onItemEnd $id');
		trace(samples.polyphony);
	}
	
	
	public function playRegion(index:Int, volume:Float, attack:Float, release:Float, delayBy:Float):Int {
		
		var region = regions[index];
		
		trace('playRegion:$index (${region.start},${region.duration}), volume:$volume, attack:$attack, release:$release, delay:$delayBy');
		
		samples.volume = volume;
		samples.attack = attack;
		samples.release = release;
		samples.offset = region.start;
		samples.duration = region.duration;
		
		var id = samples.playSample(null, delayBy);
		activeRegions.set(id, index);
		
		return id;
	}
	
	
	
	function onLoadProgress(value:Float) {
		loadProgress.emit(value);
	}
	
	
	function onArrayBufferLoaded(buffer:ArrayBuffer) {
		trace('onArrayBufferLoaded');
		arrayBuffer = buffer;
		bufferLoaded.emit();
	}
	
	
	function onDecoded(buffer:AudioBuffer) {
		samples.buffer = buffer;
		arrayBuffer = null;
		isReady = true;
		
		trace('onDecoded');
		trace(buffer);
		
		ready.emit();
	}
	
	
	function onError(err:Error) {
		trace('Error loading the AudioBuffer :(');
		trace(err);
		isReady = false;
		error.emit(err.message);
	}
}


