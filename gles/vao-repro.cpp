// Minimal GLES reproduction for maplibre-native#2905 investigation.
// No MapLibre, network, map style or Android application is required.
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static void require(bool ok, const char* operation) {
    if (!ok) {
        std::fprintf(stderr, "FAIL: %s (EGL=%x GL=%x)\n", operation, eglGetError(), glGetError());
        std::exit(1);
    }
}

static GLuint shader(GLenum type, const char* source) {
    const auto result = glCreateShader(type);
    glShaderSource(result, 1, &source, nullptr);
    glCompileShader(result);
    GLint compiled = 0;
    glGetShaderiv(result, GL_COMPILE_STATUS, &compiled);
    require(compiled, "compile shader");
    return result;
}

int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    const bool fixed = argc == 2 && std::strcmp(argv[1], "fixed") == 0;
    require(argc == 2 && (fixed || std::strcmp(argv[1], "stale") == 0), "usage: vao-repro stale|fixed");
    auto display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    require(eglInitialize(display, nullptr, nullptr), "initialize EGL");
    const EGLint attributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
                                 EGL_OPENGL_ES3_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8,
                                 EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE};
    EGLConfig config;
    EGLint count = 0;
    require(eglChooseConfig(display, attributes, &config, 1, &count) && count, "choose config");
    const EGLint surfaceAttributes[] = {EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE};
    const EGLint contextAttributes[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
    auto surface = eglCreatePbufferSurface(display, config, surfaceAttributes);
    auto context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttributes);
    require(eglMakeCurrent(display, surface, surface, context), "make current");
    std::printf("mode=%s renderer=%s version=%s\n", argv[1], glGetString(GL_RENDERER), glGetString(GL_VERSION));

    const auto vertex = shader(GL_VERTEX_SHADER, "#version 300 es\n"
        "layout(location=0) in vec2 pos; void main(){gl_Position=vec4(pos,0,1);}");
    const auto fragment = shader(GL_FRAGMENT_SHADER, "#version 300 es\n"
        "precision mediump float; out vec4 color; void main(){color=vec4(0,1,0,1);}");
    const auto program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    GLint linked = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    require(linked, "link program");
    glUseProgram(program);

    GLuint vao, vertices, oldIndices, newIndices;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glGenBuffers(1, &vertices);
    glBindBuffer(GL_ARRAY_BUFFER, vertices);
    const GLfloat triangle[] = {-1, -1, 3, -1, -1, 3};
    glBufferData(GL_ARRAY_BUFFER, sizeof(triangle), triangle, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);
    const GLushort indices[] = {0, 1, 2};
    glGenBuffers(1, &oldIndices);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, oldIndices);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // MapLibre uploads a replacement with VAO 0 bound. The existing drawable's
    // VAO still references the previous resource when that resource is deleted.
    glBindVertexArray(0);
    glGenBuffers(1, &newIndices);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, newIndices);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    glDeleteBuffers(1, &oldIndices);
    glBindVertexArray(vao);
    if (fixed) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, newIndices);
    GLint bound = 0;
    glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &bound);
    std::printf("old=%u replacement=%u bound=%d oldIsBuffer=%d\n", oldIndices, newIndices, bound, glIsBuffer(oldIndices));
    require(glGetError() == GL_NO_ERROR, "setup GL state");
    if (fixed) require(static_cast<GLuint>(bound) == newIndices, "replacement is bound");
    glViewport(0, 0, 16, 16);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    std::puts("calling glDrawElements");
    glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_SHORT, nullptr);
    glFinish();
    require(glGetError() == GL_NO_ERROR, "draw triangle");
    GLubyte pixel[4] = {};
    glReadPixels(8, 8, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
    require(glGetError() == GL_NO_ERROR, "read pixel");
    std::printf("pixel=%u,%u,%u,%u\n", pixel[0], pixel[1], pixel[2], pixel[3]);
    require(pixel[0] == 0 && pixel[1] == 255 && pixel[2] == 0 && pixel[3] == 255, "green pixel");
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vertices);
    glDeleteBuffers(1, &newIndices);
    glDeleteProgram(program);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context);
    eglDestroySurface(display, surface);
    eglTerminate(display);
    std::puts("PASS");
}
