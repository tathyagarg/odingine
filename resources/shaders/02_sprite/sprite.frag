#version 330 core

in vec2 TexCoords;
// in int isHovered;

out vec4 color;

uniform sampler2D image;
uniform int hovered;

void main()
{
    color = texture(image, TexCoords);
    if (hovered == 1) {
        color.rgb += vec3(0.2, 0.2, 0.2); // Brighten the color when hovered
    }
}
