#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform highp int u_Time; // The current time, used for noise input
uniform highp int u_Temp;   // The user's input temperature
uniform highp int u_Precip; // The user's input precipitation

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Pos;
in vec4 fs_Col;
in vec4 fs_CameraPos;
in float fs_Biome;
in float fs_Height;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float bias(float t, float b) {
  return (t / ((((1.0 / b) - 2.0) * (1.0 - t)) + 1.0));
}

float gain(float t, float g) {
  if(t < 0.5)
    return bias(t * 2.0, g) / 2.0;
  else
    return bias(t * 2.0 - 1.0, 1.0 - g) / 2.0 + 0.5;
}

float noise(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 244.1))) * 1288.002);
}

float interpNoise(float x, float y, float z) {
  int intX = int(floor(x));
  float fractX = fract(x);
  int intY = int(floor(y));
  float fractY = fract(y);
  int intZ = int(floor(z));
  float fractZ = fract(z);

  float v1 = noise(vec3(intX, intY, intZ));
  float v2 = noise(vec3(intX + 1, intY, intZ));
  float v3 = noise(vec3(intX, intY + 1, intZ));
  float v4 = noise(vec3(intX + 1, intY + 1, intZ));

  float v5 = noise(vec3(intX, intY, intZ + 1));
  float v6 = noise(vec3(intX + 1, intY, intZ + 1));
  float v7 = noise(vec3(intX, intY + 1, intZ + 1));
  float v8 = noise(vec3(intX + 1, intY + 1, intZ + 1));

  float i1 = mix(v1, v2, fractX);
  float i2 = mix(v3, v4, fractX);
  float i3 = mix(v5, v6, fractX);
  float i4 = mix(v7, v8, fractX);

  float i5 = mix(i1, i2, fractY);
  float i6 = mix(i3, i4, fractY);

  return mix(i5, i6, fractZ);
}

float fbm(vec3 p) {
  float x = p.x;
  float y = p.y;
  float z = p.z;
  float total = 0.;

  float persistence = 0.72;
  int octaves = 4;

  for(int i = 1; i <= octaves; i++) {
    float freq = pow(2.f, float(i));
    float amp = pow(persistence, float(i));
    total += interpNoise(x * freq, y * freq, z * freq) * amp;
  }
  return total;
}

float surflet(vec3 p, vec3 gridPoint) {
  vec3 t2 = abs(p - gridPoint);
  vec3 t = vec3(1.0) - 6.0 * pow(t2, vec3(5.0)) + 15.0 * pow(t2, vec3(4.0)) - 10.0 * pow(t2, vec3(3.0));
  vec3 gradient = noise(gridPoint) * 2.0 - vec3(1.0);
  vec3 diff = p - gridPoint;
  float height = dot(diff, gradient);
  return height * t.x * t.y * t.z;
}

float perlin(vec3 p) {
	float surfletSum = 0.f;
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for(int dz = 0; dz <= 1; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

float temperature(vec3 p) {
  return float(u_Temp) / 10.0 * perlin(p.xyz);
}

float precipitation(vec3 p) {
  return float(u_Precip) / 10.0 * perlin(p.zyx);
}

int biome(vec3 p) {
  float temp = temperature(p);
  float precip = precipitation(p);
  if (temp <= 0.005) {
    if (precip <= 0.005) {
      return 1;  // temperate
    } else {
      return 2;  // tundra
    }
  } else {
    if (precip <= 0.0001) {
      return 3;  // desert
    } else {
      return 4;  // tropical
    }
  }
}

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}

vec4 fog(vec3 p) {
  vec3 fbmInput = p * 0.5 + vec3(float(u_Time) * 0.0005);
  float t = fbm(fbmInput);
  if (t <= 1.15) {
    return vec4(0.0);
  } else if (t <= 1.24) {
    // light fog
    return vec4(0.1);
  }
  // clouds
  return vec4(0.5);
}

vec3 rgb(int r, int g, int b) {
  return vec3(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0);
}

vec3 terrainColor(vec3 p) {
  int biome = biome(p);
  vec3 a = vec3(0.628, 0.708, 0.788);
  vec3 b = vec3(-0.212, 0.268, 0.168);
  vec3 c = vec3(u_Color);
  vec3 d = vec3(-0.233, 0.148, 0.425);
  float h = fs_Height * 3.0;
  return palette(h, a, b, c, d);
}

void main()
{
  vec3 fbmInput = fs_Pos.xyz * 0.64 + vec3(sin(float(u_Time) * 0.0005));
  float noise = fbm(fbmInput);
  vec4 diffuseColor = vec4(terrainColor(fs_Pos.xyz), 1.0) + fog(fs_Pos.xyz);

  // calculate diffuse term for Lambert shading
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  // Avoid negative lighting values
  diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);

  // calculate specular light intensity
  float specularTerm = 0.0;
  vec4 view = normalize(fs_CameraPos - fs_Pos);
  vec4 sumViewLight = view + fs_LightVec;
  vec4 h = sumViewLight / 2.0;
  specularTerm = max(pow(dot(h, normalize(fs_Nor)), 20.0), 0.0);

  float ambientTerm = 0.4;
  float lightIntensity = diffuseTerm + ambientTerm;

  // compute final shaded color
  out_Col = vec4(diffuseColor.rgb, 1.0);
  out_Col = vec4(diffuseColor.rgb * lightIntensity, 1.0) + vec4(vec3(specularTerm), 1.0);
}
