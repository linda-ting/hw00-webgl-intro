#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform highp int u_Time;   // The current time, used for noise input

uniform highp int u_Temp;   // The user's input temperature

uniform highp int u_Precip; // The user's input precipitation

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;
out vec4 fs_CameraPos;
out float fs_Biome;
out float fs_Height;

vec4 lightPos = vec4(-5, -5, 4, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

float bias(float t, float b) {
  return (t / ((((1.0 / b) - 2.0) * (1.0 - t)) + 1.0));
}

float gain(float t, float g) {
  if(t < 0.5)
    return bias(t * 2.0, g) / 2.0;
  else
    return bias(t * 2.0 - 1.0, 1.0 - g) / 2.0 + 0.5;
}

float easeInOutQuart(float t) {
  if (t < 0.5) {
    return 8.0 * t * t * t * t;
  }
  return 1.0 - pow(-2.0 * t + 2.0, 4.0) / 2.0;
}

float parabola(float x) {
  float t = fract(x);
  return pow(4.0 * t * (1.0 - t), 2.0);
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

vec3 random3(vec3 p) {
	return fract(sin(vec3(
                    dot(p, vec3(127.1, 311.7, 99.2)),
                    dot(p, vec3(269.5, 183.3, 77.9)),
                    dot(p, vec3(381.8, 98.2, 149.4))))
                 * 1.5);
}

float worley(vec3 p) {
  p *= 60.0;
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  
  for (int z = -1; z <= 1; ++z) {
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec3 neighbor = vec3(float(x), float(y), float(z)); 
            vec3 point = random3(pInt + neighbor);
            vec3 diff = neighbor + point - pFract;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
  }
  
  return minDist;
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
      // temperate
      return 1;  
    } else {
      // tundra
      return 2;
    }
  } else {
    if (precip <= 0.0001) {
      // desert
      return 3;
    } else {
      // tropics
      return 4;
    }
  }
}

void main()
{
  fs_Pos = vs_Pos;
  fs_CameraPos = inverse(u_ViewProj) * vec4(0, 0, 0, 1);
  vec4 modelposition = u_Model * vs_Pos;

  // move sun
  lightPos.x += 10.0 * cos(float(u_Time) * 0.005);
  lightPos.y += 10.0 * sin(float(u_Time) * 0.005);
  fs_LightVec = normalize(lightPos - modelposition);

  // displace terrain
  vec3 fbmInput = modelposition.xyz * 0.64 + vec3(sin(float(u_Time) * 0.0005));
  float noise = fbm(fbmInput);
  float t = gain(noise, 0.4);
  modelposition.xyz += 0.3 * t * vec3(vs_Nor);

  int biome = biome(modelposition.xyz);
  fs_Biome = float(biome);
  if (biome == 2) {
    // add mountains to tundra
    float noise = pow(worley(modelposition.xyz / 20.0), 3.0);
    float scale = parabola(float(u_Time) * 0.001);
    modelposition.xyz += 0.18 * scale * noise * vec3(vs_Nor);
  } else if (biome == 3) {
    // add canyons to desert
    float noise = worley(modelposition.xyz / 60.0);
    float scale = (0.5 * easeInOutQuart(sin(float(u_Time) * 0.003)) + 1.0);
    float t = bias(noise, 0.9);
    if (t > 0.88) {
      modelposition.xyz -= 0.06 * scale * t * vec3(vs_Nor);
    }
  }
  fs_Height = length(modelposition.xyz);
  fs_Col = vs_Col;

  // recalculate normal
  float d = 0.001;
  float r = fs_Height;
  float theta = atan(modelposition.y, modelposition.x);
  float phi = atan(length(modelposition.xy), modelposition.z);

  vec3 px1 = vec3(r * cos(theta - d) * sin(phi),
                  r * sin(theta - d) * sin(phi),
                  r * cos(phi));
  vec3 px2 = vec3(r * cos(theta + d) * sin(phi),
                  r * sin(theta + d) * sin(phi),
                  r * cos(phi));
  vec3 py1 = vec3(r * cos(theta) * sin(phi - d),
                  r * sin(theta) * sin(phi - d),
                  r * cos(phi - d));
  vec3 py2 = vec3(r * cos(theta) * sin(phi + d),
                  r * sin(theta) * sin(phi + d),
                  r * cos(phi + d));

  float nx1 = fbm(px1);  
  float nx2 = fbm(px2);
  float ny1 = fbm(py1);
  float ny2 = fbm(py2);
  float xDiff = nx2 - nx1;
  float yDiff = ny2 - ny1;

  vec3 normal = vec3(xDiff, yDiff, sqrt(1.0 - pow(xDiff, 2.0) - pow(yDiff, 2.0)));
  vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), vs_Nor.xyz));
  vec3 bitangent = normalize(cross(tangent, vs_Nor.xyz));
  mat4 transf = mat4(tangent.x, tangent.y, tangent.z, 0.0,
                     bitangent.x, bitangent.y, bitangent.z, 0.0,
                     normal.x, normal.y, normal.z, 0.0,
                     0.0, 0.0, 0.0, 1.0);
  fs_Nor = normalize(transf * vs_Nor);

  gl_Position = u_ViewProj * modelposition;
}
