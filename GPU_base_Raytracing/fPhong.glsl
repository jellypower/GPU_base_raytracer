#version 330

#define FLT_MAX 3.402823466e+38

in vec3 N3; 
in vec3 L3; 
in vec3 V3; 
in vec3 wV;
in vec3 wP;
in vec3 wN;

out vec4 fColor;

struct Material {
	vec4  k_d;	// diffuse coefficient
	vec4  k_s;	// specular coefficient
	float n;	// specular exponent
};

struct Sphere {
	vec4     center;
	float    radius;
	Material mtl;
};

struct Ray {
	vec3 pos;
	vec3 dir;
};

struct HitInfo {
	vec4     position; // world position?
	vec3     normal;
	Material mtl;
	float t;
};

uniform mat4 uModelMat; 
uniform mat4 uViewMat; 
uniform mat4 uProjMat; 
uniform vec4 uLPos; 
uniform vec4 uLIntensity;
uniform vec4 uAmb; 
uniform vec4 uDif; 
uniform vec4 uSpc; 
uniform float uShininess; 
uniform samplerCube uCube;
uniform vec4 uEPos;
uniform int uNumSphere;
uniform Sphere uSpheres[20];
uniform int uBounceLimit;
uniform int uDrawingMode;



bool IntersectRay( inout HitInfo hit, Ray ray );

// Shades the given point and returns the computed color.
vec4 Shade(vec3 pos, vec3 normal)
{
	vec3 LPos = uLPos.xyz;
	vec4 color = vec4(1,1,1,1);

	HitInfo h;
	Ray lightRay;
	lightRay.dir = normalize(pos- LPos);
	//light�κ��� �������ϰ��� �ϴ� fragment�������� ray�� �߻�
	lightRay.pos = LPos.xyz;

	if(!IntersectRay(h, lightRay)) return color;
	// light�κ��� �������ϰ��� �ϴ� fragment��
		
	if(h.t < distance(LPos, pos) - 0.01){
	// light���� ����� ray�� ���̰� fragment������ �Ÿ����� ª���� �׸��ڸ� ����
	// 0.01�� �ε��Ҽ��� ���� � ���� ������ �����ϱ� ���� ����ġ
		color = vec4(0.4, 0.4, 0.4, 1);
	// �׸��ڰ� ����� �׸��ڰ� ����� ������ brightness return	
		}

	else{
		color = vec4(1,1,1,1);} // �׸��ڰ� ������ 1 return

	if(dot(lightRay.dir, normal) > 0){
		color = vec4(1,1,1,1);}

	return color;
}

// Intersects the given ray with all spheres in the scene
// and updates the given ` using the information of the sphere
// that first intersects with the ray.
// Returns true if an intersection is found.
bool IntersectRay( inout HitInfo hit, Ray ray )
{
	bool foundHit = false;

	float minDistRayPosToSph = FLT_MAX;	// ray�� �߻��Ͽ� ���� ����� object�� ���ø� �ؾ���
	for ( int i=0; i<uNumSphere; ++i ) { // object���� ����

		Sphere sph = uSpheres[i];

		vec3 relSphPos = vec3(sph.center.xyz) - ray.pos;
		//ray�� �������� �������� ������ ���� postion ��ǥ

		if(dot(ray.dir, relSphPos)<0) continue; // ray�� ����� ��ü�� ������ �ݴ��� ���� ����ϸ� �ȵ� 
		vec3 projectReltoRay = normalize(ray.dir) * dot(ray.dir, relSphPos) /length(ray.dir);
		vec3 rayNormalToSph = relSphPos - projectReltoRay;

		float distRayDirToSph = length(rayNormalToSph);

		if(distRayDirToSph < sph.radius && minDistRayPosToSph > length(projectReltoRay)){
		//ray���� ���� �߽��� �Ÿ��� radius���� �۾ƾ� �ϸ�, ���� ����� object�� ���ø� �ž���

			foundHit = true;
			
			minDistRayPosToSph = length(projectReltoRay);

			float len = sqrt(sph.radius * sph.radius - distRayDirToSph * distRayDirToSph);
			vec3 v = normalize(ray.dir)*len;
			vec3 sphCenterToInterPoint = - rayNormalToSph - v;

			hit.normal = normalize(sphCenterToInterPoint);
			hit.position = vec4(sph.center.xyz + sphCenterToInterPoint, sph.center.w);
			hit.mtl = sph.mtl;
			hit.t = length(relSphPos + sphCenterToInterPoint);
		}
	}

	return foundHit;
}

// Given a ray, returns the shaded color where the ray intersects a sphere.
// If the ray does not hit a sphere, returns the environment color.
vec4 RayTracer( Ray ray )
{
	
	vec4 clr;
	vec4 shade = vec4(1,1,1,1);

	vec3 V = normalize(V3); 

	HitInfo hit;

	Ray r;	// this is the reflection ray
	HitInfo h;	// reflection hit info

	if ( IntersectRay( hit, ray ) ) { // ī�޶� ��ü�� �ٶ������ �ε��� ���� �ٷ� hit
		vec3 view = normalize( -ray.dir );
		//shade = Shade(hit.position.xyz, hit.normal);
		//ī�޶󿡼� ��ü�� fragment�� �ٶ���� �� �� �׸��ڸ� ���

		r.dir = reflect(ray.dir, hit.normal);
		r.pos = hit.position.xyz;

		shade = Shade(hit.position.xyz, hit.normal);

		
		vec3 L = normalize(L3); 
		vec3 N = normalize(N3); 
		vec3 H = normalize(V+L); 

		float NL = max(dot(N, L), 0); // �븻�� �� ������ ���� Normal Light
		float VR = pow(max(dot(H, N), 0), hit.mtl.n);  // �þ߿� �� ������ ���� View Reflection(Normal)
		clr = uLIntensity*hit.mtl.k_s*VR + uLIntensity*hit.mtl.k_d*NL;

		// Compute reflections
		vec4 k_s = hit.mtl.k_s;
		for ( int bounce=0; bounce<uBounceLimit; bounce++ ) {
		// Bounce Limit��ŭ �ݺ�

			if ( hit.mtl.k_s.r + hit.mtl.k_s.g + hit.mtl.k_s.b <= 0.0 ) break;
			
			if ( IntersectRay( h, r ) ) {
			
				vec3 L = normalize(L3); 
				vec3 N = normalize(h.normal); 
				vec3 H = normalize(V+L); 

				float NL = max(dot(N, L), 0); 
				float VR = pow(max(dot(H, N), 0), h.mtl.n);

				clr = uLIntensity*h.mtl.k_s*VR + uLIntensity*h.mtl.k_d*NL;
				// ���� ��� ����� ���������� ������ �������� ���ø�
				shade *= Shade(h.position.xyz, h.normal);
				// �׸��ڴ� Ư�� ������ �� �� �� ������ ��� �־�� ������ ����

				V = -h.normal;

				r.dir = reflect(r.dir, h.normal);
				r.pos = h.position.xyz;

			} else {
				
				
				clr = k_s * texture(uCube, vec3(1,-1,1)*r.dir);
				shade *= Shade(r.pos, r.dir);

				break;	// no more reflections
			}
		}

		
		return  shade * clr;	// �׸��� ������ ray tracing ������ ���� return

	} else {
		return texture(uCube, vec3(1,-1,1)*ray.dir);	// return the environment color
	}
}

void main()
{

	vec3 N = normalize(N3); 
	vec3 L = normalize(L3); 
	vec3 V = normalize(V3); 
	vec3 H = normalize(V+L); 
	
	float NL = max(dot(N, L), 0); // �븻�� �� ������ ���� Normal Light
	float VR = pow(max(dot(H, N), 0), uShininess);  // �þ߿� �� ������ ���� View Reflection(Normal)

	if(uDrawingMode == 0) 
	{

		vec3 viewDir = wP - wV;
		vec3 dir = reflect(viewDir, wN);

		fColor = uAmb + uLIntensity*uDif*NL + uLIntensity*uSpc*VR; 
		fColor.w = 1; 

		fColor += uSpc*texture(uCube, vec3(1,-1,1)*dir);
	}
	else if(uDrawingMode == 1)
	{
		Ray r;
		r.pos = wV; // r�� ��ġ�� ī�޶��� ��ġ
		r.dir = normalize(wP - wV); // r�� dir�� ī�޶� �ش� fragment�� �ٶ󺸴� ����


		fColor = uAmb + uLIntensity*uDif*NL + uLIntensity*uSpc*VR; 
		fColor.w = 1;

		fColor += uSpc * RayTracer(r);
		
	}
}
