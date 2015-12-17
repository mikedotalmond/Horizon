package;
import hxsignal.Signal;
import motion.Actuate;
import motion.easing.*;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.loaders.Loader;
import sound.SeascapeAudio;

/**
 * ...
 * @author Mike Almond | https://github.com/mikedotalmond
 */
class AssetLoader {
	
	var stage:Container;
	
	var audioLoaded:Bool;
	var audioReady:Bool;
	var audioError:Bool;
	var backgroundReady:Bool;
	var texturesLoaded:Bool;
	var audio:SeascapeAudio;
	
	var loaderBg:Sprite;
	
	public var textures(default, null):Array<Texture>;
	public var complete(default, null):Signal<Void->Void>;

	public function new(stage:Container, audio:SeascapeAudio) {
		this.stage = stage;
		this.audio = audio;
		
		audioLoaded = audioReady = audioError = texturesLoaded = false;
		
		complete = new Signal<Void->Void>();
		
		var loader = new Loader();
		loader.add("img/horizon.png");
		loader.once('complete', backgroundLoaded);
		loader.load();
		
		audio.bufferLoaded.connect(onAudioLoaded);
		audio.ready.connect(onAudioReady);
		audio.error.connect(onAudioError);
		audio.loadBuffer();
	}
	
	function backgroundLoaded() {
		loaderBg = Sprite.fromImage("img/horizon.png");
		loaderBg.alpha = 0;
		stage.addChild(loaderBg);
		Actuate.tween(loaderBg, 1, { alpha:1 } ).ease(Quad.easeIn).onComplete(function() {
			loadTextures();	
			backgroundReady = true;
			checkState();
		});
	}
	
	function loadTextures() {
		
		var assets = ['img/horizon-bg1.jpg', 'img/horizon-bg2.jpg', 'img/horizon-bg3.jpg', 'img/horizon-bg4.jpg'];
		
		var loader = new Loader();
		loader.add(assets);
		loader.once('complete', function(_) {
			texturesLoaded = true;
			textures = [for (name in assets) Texture.fromImage(name)];		
			checkState();
		});
		
		loader.load();
	}
	
	
	function checkState() {
		
		#if debug
		trace('checkState audioError:$audioError, audioLoaded:$audioLoaded, audioReady:$audioReady, backgroundReady:$backgroundReady, texturesLoaded:$texturesLoaded');
		#end
		
		if (audioError) {
			trace('audio error');
		} else if (audioLoaded) {
			if (!audioReady) {
				if (backgroundReady && !audio.isDecoding) {
					audio.decodeBuffer();
				}
			}
		}
		
		if (texturesLoaded && audioReady) {
			complete.emit();
			Actuate.tween(loaderBg, 10, { alpha:0 } ).delay(.5).ease(Cubic.easeOut).onComplete(removeLoadDisplay);
		}
	}
	
	function removeLoadDisplay() {
		stage.removeChild(loaderBg);
		loaderBg.texture.destroy(true);
		loaderBg = null;
	}
	
	function onAudioLoaded() {
		audioLoaded = true;
		checkState();
	}
	
	function onAudioReady() {
		audioReady = true;
		checkState();
	}
	
	function onAudioError(_) {
		audioError = true;
		audioLoaded = audioReady = false;
		checkState();
	}
}