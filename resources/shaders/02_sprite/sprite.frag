#version 330 core

in vec2 TexCoords;

out vec4 color;

uniform sampler2D spriteTexture;

void main()
{
    color = texture(spriteTexture, TexCoords);
}
