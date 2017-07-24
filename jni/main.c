#include <jni.h>

#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include <android/log.h>
#include <android/asset_manager.h>
#include <android_native_app_glue.h>

#define LOG(...) ((void)__android_log_print(ANDROID_LOG_INFO, "NativeExample", __VA_ARGS__))

struct engine
{
    struct android_app* app;

    int active;
    EGLDisplay display;
    EGLSurface surface;
    EGLContext context;
    int32_t width;
    int32_t height;

    GLuint buffer;
    GLuint shader;
};

static int engine_init_display(struct engine* engine)
{
    const EGLint attribs[] =
    {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_NONE,
    };

    EGLDisplay display;;
    if ((display = eglGetDisplay(EGL_DEFAULT_DISPLAY)) == EGL_NO_DISPLAY)
    {
        LOG("error with eglGetDisplay");
        return -1;
    }

    if (!eglInitialize(display, 0, 0))
    {
        LOG("error with eglInitialize");
        return -1;
    }

    EGLConfig config;
    EGLint numConfigs;
    if (!eglChooseConfig(display, attribs, &config, 1, &numConfigs))
    {
        LOG("error with eglChooseConfig");
        return -1;
    }

    EGLint format;
    if (!eglGetConfigAttrib(display, config, EGL_NATIVE_VISUAL_ID, &format))
    {
        LOG("error with eglGetConfigAttrib");
        return -1;
    }

    ANativeWindow_setBuffersGeometry(engine->app->window, 0, 0, format);

    EGLSurface surface;
    if (!(surface = eglCreateWindowSurface(display, config, engine->app->window, NULL)))
    {
        LOG("error with eglCreateWindowSurface");
        return -1;
    }

    const EGLint ctx_attrib[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext context;
    if (!(context = eglCreateContext(display, config, NULL, ctx_attrib)))
    {
        LOG("error with eglCreateContext");
        return -1;
    }

    if (eglMakeCurrent(display, surface, surface, context) == EGL_FALSE)
    {
        LOG("error with eglMakeCurrent");
        return -1;
    }

    LOG("GL_VENDOR = %s", glGetString(GL_VENDOR));
    LOG("GL_RENDERER = %s", glGetString(GL_RENDERER));
    LOG("GL_VERSION = %s", glGetString(GL_VERSION));

    EGLint w, h;
    eglQuerySurface(display, surface, EGL_WIDTH, &w);
    eglQuerySurface(display, surface, EGL_HEIGHT, &h);

    engine->display = display;
    engine->context = context;
    engine->surface = surface;
    engine->width = w;
    engine->height = h;

    AAsset* vasset = AAssetManager_open(engine->app->activity->assetManager, "vertex.glsl", AASSET_MODE_BUFFER);
    if (!vasset)
    {
        LOG("error opening vertex.glsl");
        return -1;
    }
    const GLchar* vsrc = AAsset_getBuffer(vasset);
    GLint vlen = AAsset_getLength(vasset);

    GLuint v = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(v, 1, &vsrc, &vlen);
    glCompileShader(v);

    AAsset_close(vasset);

    AAsset* fasset = AAssetManager_open(engine->app->activity->assetManager, "fragment.glsl", AASSET_MODE_BUFFER);
    if (!fasset)
    {
        LOG("error opening fragment.glsl");
        return -1;
    }
    const GLchar* fsrc = AAsset_getBuffer(fasset);
    GLint flen = AAsset_getLength(fasset);

    GLuint f = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(f, 1, &fsrc, &flen);
    glCompileShader(f);

    AAsset_close(fasset);

    GLuint p = glCreateProgram();
    glAttachShader(p, v);
    glAttachShader(p, f);

    glBindAttribLocation(p, 0, "vPosition");
    glBindAttribLocation(p, 1, "vColor");
    glLinkProgram(p);

    glDeleteShader(v);
    glDeleteShader(f);
    glUseProgram(p);

    const float buf[] =
    {
         0.0f,  0.5f, 1.f, 0.f, 0.f,
        -0.5f, -0.5f, 0.f, 1.f, 0.f,
         0.5f, -0.5f, 0.f, 0.f, 1.f,
    };

    GLuint b;
    glGenBuffers(1, &b);
    glBindBuffer(GL_ARRAY_BUFFER, b);
    glBufferData(GL_ARRAY_BUFFER, sizeof(buf), buf, GL_STATIC_DRAW);

    engine->buffer = b;
    engine->shader = p;

    return 0;
}

static void engine_draw_frame(struct engine* engine)
{
    if (engine->display == NULL)
    {
        return;
    }

    glClearColor(0.258824f, 0.258824f, 0.435294f, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(engine->shader);

    glBindBuffer(GL_ARRAY_BUFFER, engine->buffer);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, (2+3)*sizeof(float), NULL);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, (2+3)*sizeof(float), (void*)(2*sizeof(float)));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    glDrawArrays(GL_TRIANGLES, 0, 3);

    eglSwapBuffers(engine->display, engine->surface);
}

static void engine_term_display(struct engine* engine)
{
    if (engine->display != EGL_NO_DISPLAY)
    {
        glDeleteProgram(engine->shader);
        glDeleteBuffers(1, &engine->buffer);

        eglMakeCurrent(engine->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (engine->context != EGL_NO_CONTEXT)
        {
            eglDestroyContext(engine->display, engine->context);
        }
        if (engine->surface != EGL_NO_SURFACE)
        {
            eglDestroySurface(engine->display, engine->surface);
        }
        eglTerminate(engine->display);
    }
    engine->active = 0;
    engine->display = EGL_NO_DISPLAY;
    engine->context = EGL_NO_CONTEXT;
    engine->surface = EGL_NO_SURFACE;
}

static int32_t engine_handle_input(struct android_app* app, AInputEvent* event)
{
    return 0;
}

static void engine_handle_cmd(struct android_app* app, int32_t cmd)
{
    struct engine* engine = (struct engine*)app->userData;
    switch (cmd)
    {
        case APP_CMD_INIT_WINDOW:
            if (engine->app->window != NULL)
            {
                engine_init_display(engine);
                engine_draw_frame(engine);
            }
            break;

        case APP_CMD_TERM_WINDOW:
            engine_term_display(engine);
            break;
        
        case APP_CMD_GAINED_FOCUS:
            engine->active = 1;
            break;

        case APP_CMD_LOST_FOCUS:
            engine->active = 0;
            engine_draw_frame(engine);
            break;
    }
}

void android_main(struct android_app* state)
{
    app_dummy();

    struct engine engine;
    memset(&engine, 0, sizeof(engine));

    state->userData = &engine;
    state->onAppCmd = engine_handle_cmd;
    state->onInputEvent = engine_handle_input;
    engine.app = state;

    while (1)
    {
        int ident;
        int events;
        struct android_poll_source* source;

        while ((ident=ALooper_pollAll(engine.active ? 0 : -1, NULL, &events, (void**)&source)) >= 0)
        {
            if (source != NULL)
            {
                source->process(state, source);
            }

            if (state->destroyRequested != 0)
            {
                engine_term_display(&engine);
                return;
            }
        }

        if (engine.active)
        {
            engine_draw_frame(&engine);
        }
    }
}
