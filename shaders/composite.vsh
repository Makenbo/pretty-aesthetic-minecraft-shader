#version 420

out vec2 texCoord;

void main()
{
   gl_Position = ftransform();
   texCoord = gl_MultiTexCoord0.st;
}
