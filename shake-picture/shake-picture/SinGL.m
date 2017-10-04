//
//  SinGL.m
//  shake-picture
//
//  Created by suntongmian on 2017/10/4.
//  Copyright © 2017年 Pili Engineering, Qiniu Inc. All rights reserved.
//

#import "SinGL.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import "GLProgram.h"

typedef enum {
    kGLNoRotation,
    kGLRotateLeft,
    kGLRotateRight,
    kGLFlipVertical,
    kGLFlipHorizonal,
    kGLRotateRightFlipVertical,
    kGLRotateRightFlipHorizontal,
    kGLRotate180
} GLRotationMode;

@interface SinGL ()
{
    GLRotationMode inputRotation;

    CAEAGLLayer *eaglLayer;
    
    EAGLRenderingAPI eaglRenderingAPI;
    EAGLContext *eaglContext;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    GLuint displayRenderbuffer, displayFramebuffer;
    GLint backingWidth, backingHeight;
    CGSize boundsSizeAtFrameBufferEpoch;
    
    CVOpenGLESTextureRef texture;
    CVOpenGLESTextureCacheRef textureCache;
}

// Initialization and teardown
- (void)commonInit;

// Managing the display FBOs
- (void)createDisplayFramebuffer;
- (void)destroyDisplayFramebuffer;

@end

@implementation SinGL

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // The frame buffer needs to be trashed and re-created when the view size changes.
    if (!CGSizeEqualToSize(self.bounds.size, boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        [self destroyDisplayFramebuffer];
        [self createDisplayFramebuffer];
    }
}

// Initialization and teardown
- (void)commonInit {
    inputRotation = kGLNoRotation;

    eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    // Set the context into which the frames will be drawn.
    eaglRenderingAPI = kEAGLRenderingAPIOpenGLES3;
    eaglContext = [[EAGLContext alloc] initWithAPI:eaglRenderingAPI];
    
    if (!eaglContext || ![EAGLContext setCurrentContext:eaglContext]) {
        NSAssert(NO, @"failed to setup EAGLContext");
    }
    
    //  Create a new CVOpenGLESTexture cache
    CVReturn ret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, eaglContext, NULL, &textureCache);
    if (ret) {
        NSAssert(NO, @"CVOpenGLESTextureCacheCreater: %d", ret);
    }
    
    [self loadShaders];
    
    [self createDisplayFramebuffer];
}

- (void)loadShaders {
    if ([EAGLContext currentContext] != eaglContext) {
        [EAGLContext setCurrentContext:eaglContext];
    }
    
    displayProgram = [[GLProgram alloc] initWithVertexShaderFilename:@"SinGL" fragmentShaderFilename:@"SinGL"];
    if (!displayProgram.initialized) {
        [displayProgram addAttribute:@"position"];
        [displayProgram addAttribute:@"inputTextureCoordinate"];
        
        if (![displayProgram link]) {
            NSString *progLog = [displayProgram programLog];
            NSLog(@"Program link log: %@", progLog);
            NSString *fragLog = [displayProgram fragmentShaderLog];
            NSLog(@"Fragment shader compile log: %@", fragLog);
            NSString *vertLog = [displayProgram vertexShaderLog];
            NSLog(@"Vertex shader compile log: %@", vertLog);
            displayProgram = nil;
            NSAssert(NO, @"Filter shader link failed");
        }
    }
    
    displayPositionAttribute = [displayProgram attributeIndex:@"position"];
    displayTextureCoordinateAttribute = [displayProgram attributeIndex:@"inputTextureCoordinate"];
    displayInputTextureUniform = [displayProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputTexture" for the fragment shader
    
    [displayProgram use];
    
    glEnableVertexAttribArray(displayPositionAttribute);
    glEnableVertexAttribArray(displayTextureCoordinateAttribute);
}

// Managing the display FBOs
- (void)createDisplayFramebuffer {
    if ([EAGLContext currentContext] != eaglContext) {
        [EAGLContext setCurrentContext:eaglContext];
    }
    
    glGenFramebuffers(1, &displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glGenRenderbuffers(1, &displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    
    [eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if ( (backingWidth == 0) || (backingHeight == 0) ) {
        NSLog(@"Backing width: 0 || height: 0");

        [self destroyDisplayFramebuffer];
        return;
    }
    
    NSLog(@"Backing width: %d, height: %d", backingWidth, backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);
    
    GLuint framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
    boundsSizeAtFrameBufferEpoch = self.bounds.size;
}

- (void)destroyDisplayFramebuffer {
    if ([EAGLContext currentContext] != eaglContext) {
        [EAGLContext setCurrentContext:eaglContext];
    }
    
    if (displayFramebuffer) {
        glDeleteFramebuffers(1, &displayFramebuffer);
        displayFramebuffer = 0;
    }
    
    if (displayRenderbuffer) {
        glDeleteRenderbuffers(1, &displayRenderbuffer);
        displayRenderbuffer = 0;
    }
}

- (void)setDisplayFramebuffer {
    if (!displayFramebuffer) {
        [self createDisplayFramebuffer];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glViewport(0, 0, backingWidth, backingHeight);
}

- (void)presentFramebuffer {
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    
    [eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)renderBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    if ([EAGLContext currentContext] != eaglContext) {
        [EAGLContext setCurrentContext:eaglContext];
    }
    
    [displayProgram use];
    
    [self setDisplayFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self cleanUpTexture];
    
    glActiveTexture(GL_TEXTURE4);
    // Create a CVOpenGLESTexture from the CVImageBuffer
    size_t frameWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t frameHeight = CVPixelBufferGetHeight(pixelBuffer);
    CVReturn ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                textureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RGBA,
                                                                (GLsizei)frameWidth,
                                                                (GLsizei)frameHeight,
                                                                GL_BGRA,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &texture);
    if (ret) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage ret: %d", ret);
    }
    glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(displayInputTextureUniform, 4);
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [self textureCoordinatesForRotation:inputRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self presentFramebuffer];
        
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)cleanUpTexture {
    if(texture) {
        CFRelease(texture);
        texture = NULL;
    }
    CVOpenGLESTextureCacheFlush(textureCache, 0);
}

- (const GLfloat *)textureCoordinatesForRotation:(GLRotationMode)rotationMode {
    //    static const GLfloat noRotationTextureCoordinates[] = {
    //        0.0f, 0.0f,
    //        1.0f, 0.0f,
    //        0.0f, 1.0f,
    //        1.0f, 1.0f,
    //    };
    
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    switch(rotationMode) {
        case kGLNoRotation: return noRotationTextureCoordinates;
        case kGLRotateLeft: return rotateLeftTextureCoordinates;
        case kGLRotateRight: return rotateRightTextureCoordinates;
        case kGLFlipVertical: return verticalFlipTextureCoordinates;
        case kGLFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kGLRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kGLRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kGLRotate180: return rotate180TextureCoordinates;
    }
}

- (void)dealloc {
    
}

@end
