#define _CRT_SECURE_NO_WARNINGS

#include <vgl.h>
#include <InitShader.h>

#include <string>
#include "MyCube.h"
#include "MySphere.h"
#include "Targa.h"

#include <vec.h>
#include <mat.h>


MyCube cube;
MySphere sphere;

GLuint program;
GLuint phong_prog;
GLuint cube_prog;

float g_Time = 0;
float g_aspect = 1;

struct SphereData
{
	vec4 center;
	float radius;
	vec4 k_d;
	vec4 k_s;
	float shiny;
};


int g_NumSphere = 10;
const int g_NumSphereMax = 20;
const int g_NumSphereMin = 2;

int g_BounceLimit = 1;
const int g_BounceLimitMax = 10;
const int g_BounceLimitMin = 0;

int g_DrawingMode = 0;							// 0 : Rasterize
												// 1 : Raytracing (GPU)



SphereData* g_Sph = nullptr;
void myInitSphereData()
{
	
	if (g_Sph != nullptr) delete[] g_Sph;
	g_Sph = new SphereData[g_NumSphereMax];

	g_Sph[0].center = vec4(0, -10001, 0, 1);
	g_Sph[0].radius = 10000;
	g_Sph[0].k_d = vec4(0.1, 0.1, 0.2, 1);
	g_Sph[0].k_s = vec4(0.2, 0.2, 0.2, 1);
	g_Sph[0].shiny = 10;

	g_Sph[1].center = vec4(0, -0, 0, 1);
	g_Sph[1].radius = 1;
	g_Sph[1].k_d = vec4(0.5, 0.0, 0.0, 1);
	g_Sph[1].k_s = vec4(0.8, 0.8, 0.8, 1);
	g_Sph[1].shiny = 100;

	
	for (int i = 2; i < g_NumSphereMax; i++)
	{
		float size = sqrt(g_NumSphereMax) / 2.0f + 1;
		bool valid = false;
		vec4 cent(0, 0, 0, 1);
		float r;				
		while (valid == false)
		{
			float a = (rand()%10000)/10000.0f * 3.141592 * 2.0f;
			float b = (rand() % 10000) / 10000.0f * size;
			cent[0] = cos(a) * b;
			cent[2] = sin(a) * b;
			r = (rand() % 10000) / 10000.0f * 0.6 + 0.1;
			cent[1] = r - 1;
			valid = true;
			for (int j = 0; j < i; j++) {
				float len = length(g_Sph[j].center - cent);
				if (len < r + g_Sph[j].radius) {
					valid = false;
					break;
				}
			}
		}
		float ks = (rand() % 1000) / 1000.0f;
		g_Sph[i].center = cent;
		g_Sph[i].radius = r;
		g_Sph[i].k_d = vec4((rand() % 1000) / 1000.0f, (rand() % 1000) / 1000.0f, (rand() % 1000) / 1000.0f, 1);
		g_Sph[i].k_s = vec4(ks, ks, ks, 1);
		g_Sph[i].shiny = (rand() % 1000);

	}
}


mat4 myLookAt(vec3 eye, vec3 at, vec3 up)
{
	mat4 V = mat4(1.0f);
	
	up = normalize(up);
	vec3 n = normalize(at - eye);
	float a = dot(up, n);
	vec3 v = normalize(up-a*n);
	vec3 w = cross(n, v);

	V[0] = vec4(w, dot(-w, eye));
	V[1] = vec4(v, dot(-v, eye));
	V[2] = vec4(-n, dot(n, eye));
	
	return V;
}

mat4 myOrtho(float l, float r, float b, float t, float zNear, float zFar)
{
	vec3 center = vec3((l+r)/2, (b+t)/2, -(zNear)/2);
	mat4 T = Translate(-center);
	mat4 S = Scale(2/(r-l), 2/(t-b), -1/(-zNear+zFar));
	mat4 V = S*T;

	return V;
}

mat4 myPerspective(float angle, float aspect, float zNear, float zFar)
{
	float rad = angle*3.141592/180.0f;
	mat4 V(1.0f);
	float h = 2*zFar*tan(rad/2);
	float w = aspect*h;
	mat4 S = Scale(2/w, 2/h, 1/zFar);

	float c = -zNear/zFar;
	
	mat4 Mpt(1.0f);
	Mpt[2] = vec4(0, 0, 1/(c+1), -c/(c+1));
	Mpt[3] = vec4(0, 0, -1, 0);
	
	V = Mpt*S;
	return V;
}

void myTextureInit()
{
	GLuint myTex;
	glGenTextures(1, &myTex);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_CUBE_MAP, myTex);

	std::string str = "museum_";
//	std::string str = "church_";
	std::string extension = ".tga";
	std::string dir[6] = {"posx", "negy", "posz", "negx", "posy", "negz"};
	GLenum target[6] = { GL_TEXTURE_CUBE_MAP_POSITIVE_X,
						 GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
						 GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
						 GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
						 GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
						 GL_TEXTURE_CUBE_MAP_NEGATIVE_Z };

	for (int i = 0; i < 6; i++)
	{
		STGA img;
		std::string filename = str + dir[i] + extension;
		img.loadTGA(filename.c_str());
		glTexImage2D(target[i], 0, GL_RGB,
			img.width, img.height, 0, GL_BGR, GL_UNSIGNED_BYTE, img.data);
		img.destroy();
	}
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, 
		            GL_LINEAR);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, 
		            GL_LINEAR);
}

void myInit()
{
	cube.Init();
	sphere.Init(40,40);
		
	cube_prog = InitShader("vcube.glsl", "fcube.glsl");
	phong_prog = InitShader("vPhong.glsl", "fPhong.glsl");
	
	myTextureInit();	
	myInitSphereData();
}

void drawCubeMap(mat4 ViewMat, mat4 ProjMat, vec4 ePos)
{
	glUseProgram(cube_prog);
	GLuint uModelMat = glGetUniformLocation(cube_prog, "uModelMat");
	GLuint uViewMat = glGetUniformLocation(cube_prog, "uViewMat");
	GLuint uProjMat = glGetUniformLocation(cube_prog, "uProjMat");
	GLuint uCube = glGetUniformLocation(cube_prog, "uCube");
	GLuint uEPos = glGetUniformLocation(cube_prog, "uEPos");

	glUniformMatrix4fv(uModelMat, 1, true, Scale(50,50,50));
	glUniformMatrix4fv(uViewMat, 1, true, ViewMat);
	glUniformMatrix4fv(uProjMat, 1, true, ProjMat);
	glUniform1i(uCube, 0);
	glUniform4f(uEPos, ePos[0], ePos[1], ePos[2], 1);

	cube.Draw(cube_prog);
}


void display()
{
	glClearColor(0,0,0,1);
	glClear(GL_DEPTH_BUFFER_BIT|GL_COLOR_BUFFER_BIT);
	glEnable(GL_DEPTH_TEST);

	vec3 ePos = vec3(4*cos(g_Time*3.141592 / 20.0f),1,4*sin(g_Time * 3.141592 / 20.0f));
	
	mat4 ModelMat = Scale(1,1,1);
	mat4 ViewMat = myLookAt(ePos, vec3(0,0,0), vec3(0,1,0));
	mat4 ProjMat = myPerspective(45, g_aspect, 0.01, 100.0f);

	drawCubeMap(ViewMat, ProjMat, ePos);

	glUseProgram(phong_prog);
	GLuint uModelMat = glGetUniformLocation(phong_prog, "uModelMat");
	GLuint uViewMat = glGetUniformLocation(phong_prog, "uViewMat");
	GLuint uProjMat = glGetUniformLocation(phong_prog, "uProjMat");
	GLuint uLPos = glGetUniformLocation(phong_prog, "uLPos");
	GLuint uLIntensity = glGetUniformLocation(phong_prog, "uLIntensity");	
	GLuint uAmb = glGetUniformLocation(phong_prog, "uAmb");
	GLuint uDif = glGetUniformLocation(phong_prog, "uDif");
	GLuint uSpc = glGetUniformLocation(phong_prog, "uSpc");
	GLuint uShininess = glGetUniformLocation(phong_prog, "uShininess");
	GLuint uCube = glGetUniformLocation(phong_prog, "uCube");
	GLuint uEPos = glGetUniformLocation(phong_prog, "uEPos");
	GLuint uNumSphere = glGetUniformLocation(phong_prog, "uNumSphere");
	GLuint uBounceLimit = glGetUniformLocation(phong_prog, "uBounceLimit");
	GLuint uDrawingMode = glGetUniformLocation(phong_prog, "uDrawingMode");

	// Define Light Properties
	vec4 lPos = vec4(0, 1000, 0, 1);			 
	vec4 lIntensity = vec4(1, 1, 1, 1);

	glUniformMatrix4fv(uViewMat, 1, true, ViewMat);
	glUniformMatrix4fv(uProjMat, 1, true, ProjMat);
	glUniform4f(uLPos, lPos[0], lPos[1], lPos[2], lPos[3]);
	glUniform4f(uLIntensity, lIntensity[0], lIntensity[1], lIntensity[2], lIntensity[3]);
	glUniform1i(uCube, 0);
	glUniform4f(uEPos, ePos[0], ePos[1], ePos[2], 1);
	glUniform1i(uNumSphere, g_NumSphere);
	glUniform1i(uBounceLimit, g_BounceLimit);
	glUniform1i(uDrawingMode, g_DrawingMode);

	for (int i = 0; i < g_NumSphere; i++)
	{
		std::string str;
		str = "uSpheres[" + std::to_string(i) + "].center";
		glUniform4f(glGetUniformLocation(phong_prog, str.c_str()), g_Sph[i].center[0], g_Sph[i].center[1], g_Sph[i].center[2], g_Sph[i].center[3]);
		
		str = "uSpheres[" + std::to_string(i) + "].radius";
		glUniform1f(glGetUniformLocation(phong_prog, str.c_str()), g_Sph[i].radius);

		str = "uSpheres[" + std::to_string(i) + "].mtl.k_d";
		glUniform4f(glGetUniformLocation(phong_prog, str.c_str()), g_Sph[i].k_d[0], g_Sph[i].k_d[1], g_Sph[i].k_d[2], g_Sph[i].k_d[3]);
		
		str = "uSpheres[" + std::to_string(i) + "].mtl.k_s";
		glUniform4f(glGetUniformLocation(phong_prog, str.c_str()), g_Sph[i].k_s[0], g_Sph[i].k_s[1], g_Sph[i].k_s[2], g_Sph[i].k_d[3]);
		
		str = "uSpheres[" + std::to_string(i) + "].mtl.n";
		glUniform1f(glGetUniformLocation(phong_prog, str.c_str()), g_Sph[i].shiny);
	}

	for (int i = 0; i < g_NumSphere; i++)
	{
		// Set Material Properties for the current sphere
		vec4 mAmb = vec4(0.0, 0.0, 0.0, 1);
		vec4 mDif = g_Sph[i].k_d;
		vec4 mSpc = g_Sph[i].k_s;
		float mShiny = g_Sph[i].shiny;	
		
		ModelMat = Translate(g_Sph[i].center) * Scale(g_Sph[i].radius, g_Sph[i].radius, g_Sph[i].radius);

		glUniformMatrix4fv(uModelMat, 1, true, ModelMat);
		glUniform4f(uAmb, mAmb[0], mAmb[1], mAmb[2], mAmb[3]);
		glUniform4f(uDif, mDif[0], mDif[1], mDif[2], mDif[3]);
		glUniform4f(uSpc, mSpc[0], mSpc[1], mSpc[2], mSpc[3]);
		glUniform1f(uShininess, mShiny);

		sphere.Draw(phong_prog);
	}
	
	glutSwapBuffers();
}


void idle()
{
	g_Time += 0.016f;
	Sleep(16);					// for vSync
	glutPostRedisplay();
}

void reshape(int w, int h)
{
	glViewport(0, 0, w, h);
	
	g_aspect = w/float(h);
	glutPostRedisplay();
}

void keyboard(unsigned char c, int x, int y)
{
	switch (c)
	{
	case '1':	
		g_NumSphere = std::min(++g_NumSphere, g_NumSphereMax);
		printf("Num of Sphere:%d\n", g_NumSphere);
		break;
	case '2':	
		g_NumSphere = std::max(--g_NumSphere, g_NumSphereMin);
		printf("Num of Sphere:%d\n", g_NumSphere);
		break;
	case '3':
		g_BounceLimit = std::min(++g_BounceLimit, g_BounceLimitMax);
		printf("Num of Bound Limit:%d\n", g_BounceLimit);
		break;
	case '4':
		g_BounceLimit = std::max(--g_BounceLimit, g_BounceLimitMin);
		printf("Num of Bound Limit:%d\n", g_BounceLimit);
		break;
	case 'r':	
		myInitSphereData();				
		break;
	case ' ':	
		if (g_DrawingMode == 0)
		{
			g_DrawingMode = 1;
			printf("RayTracing(GPU) Mode\n");
		}
		else
		{
			g_DrawingMode = 0;
			printf("Rasterizing Mode\n");
		}
		break;	
	default:									
		break;
	}
	
	
}

void diesplayManual() {
	printf("\n\n\n");

	printf("==============GPU Base Raytracer without RT-core---=============\n");
	printf("\t1. Space: Enable/Disable RayTracing\n");
	printf("\t2. 1: Increase num of Sphere\n");
	printf("\t3. 2: Decrease num of Sphere\n");
	printf("\t4. 3: Increase num of bounc limit\n");
	printf("\t5. 4: Decrease num of bounc limit\n");
	printf("\t6. r: Reset the position of all spheres\n");
	printf("================================================================\n");

}

int main(int argc, char ** argv)
{
	glutInit(&argc, argv);

	glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH);
	glutInitWindowSize(1024, 512);

	glutCreateWindow("RayTracer(GPU) Homework");

	glewExperimental = true;
	glewInit();

	printf("OpenGL %s, GLSL %s\n",	glGetString(GL_VERSION),
									glGetString(GL_SHADING_LANGUAGE_VERSION));

	diesplayManual();
	
	myInit();
	glutDisplayFunc(display);
	glutIdleFunc(idle);
	glutReshapeFunc(reshape);
	glutKeyboardFunc(keyboard);
	glutMainLoop();

	return 0;
}
