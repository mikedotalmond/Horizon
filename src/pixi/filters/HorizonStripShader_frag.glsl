#ifdef GL_ES
precision mediump float;
precision mediump int;
#else
precision highp float;
#endif

uniform sampler2D textureA;
uniform sampler2D textureB;

uniform vec2 seeds;
uniform float position;

uniform vec4 stripsA;
uniform vec3 stripsB;

uniform vec3 yOffsets; // x = amount, y=centre, z=angle/skew

//varying vec4 vertColor;
varying vec2 vTextureCoord;

float rnd(vec2 x)
{
    return fract(sin(dot(x.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main(void) {
  
  float vx = vTextureCoord.x;
  
  // prandom numbers for this pixel
  float rX = rnd(seeds.x * vTextureCoord);
  float rY = rnd(seeds.y * vTextureCoord);
  
  // get y position, and add offsets to scale and position some Y noise
  float y = vTextureCoord.y + (rY - yOffsets.z) * vTextureCoord.y * (fract(vx) - yOffsets.y) * yOffsets.x;
  
  vec2 sliceACoord = vec2(0, y);
  vec2 sliceBCoord = vec2(0, y);
  
  float f2;
  
  if(vx < stripsA[1]) {
	sliceACoord.x = stripsA[0];
	sliceBCoord.x = stripsA[1];
  }
  else if(vx < stripsA[2]) 	{
	sliceACoord.x = stripsA[1];
	sliceBCoord.x = stripsA[2];
  }
  else if(vx < stripsA[3]) {
	sliceACoord.x = stripsA[2];
	sliceBCoord.x = stripsA[3];
  }
  else if(vx < stripsB[0]) {
	sliceACoord.x = stripsA[3];
	sliceBCoord.x = stripsB[0];
  }
  else if(vx < stripsB[1]) {
	sliceACoord.x = stripsB[0];
	sliceBCoord.x = stripsB[1];
  }
  else {
	sliceACoord.x = stripsB[1];
	sliceBCoord.x = stripsB[2];
  }
  
  f2 =  (vx - sliceACoord.x) / (sliceBCoord.x - sliceACoord.x);
 
  // lerp between the two sampling positions
 
  vec4 mixA = ( 1.0 - f2 ) * texture2D(textureA, sliceACoord) + f2 * texture2D(textureA, sliceBCoord);
  vec4 mixB = ( 1.0 - f2 ) * texture2D(textureB, sliceACoord) + f2 * texture2D(textureB, sliceBCoord);
  
  vec4 mix = (1.0-position) * mixA + position * mixB;
  
  // add noise (monochromatic)
  mix += (rX - 0.5) * .04; // noiseAmt
  
  // output
  gl_FragColor = mix;
}
