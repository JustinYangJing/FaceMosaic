//
//  GLView.m
//  FaceMosaic
//
//  Created by JustinYang on 2021/4/19.
//

#import "GLView.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/EAGL.h>
#import <AVFoundation/AVFoundation.h>
#include "Shader.hpp"
#include "stb_image.h"
@implementation GLView
{
    GLuint _fbo;
    GLuint _rbo;
    EAGLContext *_context;
    Shader  *_glsl;
    unsigned int _VAO;
    unsigned int _VBO;
    unsigned int _textureID;
}

+(Class)layerClass{
    return [CAEAGLLayer class];
}
-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self layerInit];
      
        [self setFBOAndRBO];
        
    }
    return self;
}

-(void)layerInit{
    CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
    
    layer.opaque = NO;
    layer.contentsScale = [UIScreen mainScreen].scale;
    layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:@(NO),
                                kEAGLDrawablePropertyRetainedBacking,
                                kEAGLColorFormatRGBA8,
                                kEAGLDrawablePropertyColorFormat,nil];

}

-(void)setFBOAndRBO{
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    _context.multiThreaded = YES;
    [EAGLContext setCurrentContext:_context];
    
    
    glGenFramebuffers(1, &_fbo);
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), _fbo);
    
    glGenRenderbuffers(1, &_rbo);
    glBindRenderbuffer(GLenum(GL_RENDERBUFFER), _rbo);
    
    glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), _rbo);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    
    NSAssert(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE), @"初始化fbo出错");
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    
    NSString *vertPath = [[NSBundle mainBundle] pathForResource:@"glsl" ofType:@"vert"];
    NSString *fragPath = [[NSBundle mainBundle] pathForResource:@"glsl" ofType:@"frag"];
    
    _glsl = new Shader(vertPath.UTF8String,fragPath.UTF8String);
   
    GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
        1.0f, 1.0f, 0.0f , 1.0f, 1.0f,
        1.0f, -1.0f, 0.0f , 1.0f, 0.0f,

        1.0f, 1.0f, 0.0f , 1.0f, 1.0f,
        -1.0f, -1.0f, 0.0f , 0.0f, 0.0f,
        -1.0f, 1.0f, 0.0f , 0.0f, 1.0f,
    };
    
    glGenTextures(1, &_textureID);
    
    
    glGenVertexArrays(1,&_VAO);
    glGenBuffers(1, &_VBO);
    glBindVertexArray(_VAO);
    glBindBuffer(GL_ARRAY_BUFFER,_VBO);

    glBufferData(GL_ARRAY_BUFFER,sizeof(vertices), vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5* sizeof(float), (void *)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(float), (void *)(3 *sizeof(float)));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}
-(void)setBlurRadius:(int)radius pixelSize:(CGSize)size{
    if (_glsl != NULL){
        delete _glsl;
    }
    NSString *vertPath = [[NSBundle mainBundle] pathForResource:@"glsl" ofType:@"vert"];
    _glsl = new Shader();
    
    NSMutableString *shaderString = [[NSMutableString alloc] init];
    [shaderString appendString:@"\
     #version 300 es\n\
     precision highp float;\n\
     precision highp int;\n\
     precision highp sampler2D;\n\
     out vec4 FragColor;\n\
     uniform sampler2D tex;\n\
     uniform vec2 faceBounds[8];\n\
     uniform int faces; \n\
     in vec2 texCoord;\n"];
    CGFloat sigma = 100.0;
    
    CGFloat *kernel = (CGFloat *)malloc(sizeof(CGFloat)*(radius*2 + 1)*(radius*2 + 1));
    int index = 0;
    for (int row = radius; row > -(radius+1); row--){
        for (int col = -radius ; col < (radius + 1); col++){
            CGFloat value = 1/(2 * M_PI * sigma*sigma) * exp(-(pow(col, 2) + pow(row, 2))/(2*sigma*sigma));
            kernel[index++] = value;
        }
    }
   
    CGFloat sum = 0;
    for (int i = 0; i < index; i++) {
        sum += kernel[i];
    }
    
    [shaderString appendFormat:@"const float kernel[%d] = float[](", index];
    for (int i = 0 ; i < index; i++) {
        [shaderString appendFormat:@"%.9f,", kernel[i]/sum];
    }
    [shaderString replaceCharactersInRange:NSMakeRange(shaderString.length - 1, 1) withString:@");\n"];
    free(kernel);
    kernel = NULL;
    
    CGFloat *offset = (CGFloat *)malloc(sizeof(CGFloat)*(radius*2 + 1)*(radius*2 + 1)*2);
    index = 0;
    for (int row = radius; row > -(radius+1); row--){
        for (int col = -radius ; col < (radius + 1); col++){
            CGFloat x = col/size.width;
            CGFloat y = row/size.height;
            offset[index++] = x;
            offset[index++] = y;
        }
    }
    
    [shaderString appendFormat:@" const vec2 offsets[%d] = vec2[](",index/2];
    for (int i = 0; i < index; ) {
        [shaderString appendFormat:@"vec2(%f,%f),",offset[i],offset[i+1]];
        i = i + 2;
    }
    free(offset);
    offset = NULL;
    [shaderString replaceCharactersInRange:NSMakeRange(shaderString.length - 1, 1) withString:@");\n"];
    
    index = index/2;
    [shaderString appendFormat:@"\
    vec4 blur(){\n\
        vec3 color = vec3(0.0);\n\
        for (int i = 0; i < %d; i++) {\n\
            vec4 tColor = texture(tex,texCoord.st + offsets[i]);\n\
            color += vec3(tColor.bgr)*kernel[i];\n\
        }\n\
        return vec4(color,1.0);\n\
     }\n", index];
    
    [shaderString appendFormat:@"\
    void main()\n\
    {\n\
        vec4 color = texture(tex,texCoord);\n\
        FragColor = vec4(color.b,color.g,color.r,1.0);\n\
        int realFaces = min(faces,4);\n\
        for (int i = 0; i < realFaces; i++) {\n\
            if (texCoord.x > faceBounds[2*i].x && texCoord.x < faceBounds[2*i+1].x && texCoord.y > faceBounds[2*i].y && texCoord.y < faceBounds[2*i+1].y) {\n\
                FragColor = blur();\n\
            }\n\
        }\n\
     }\n"];
    
    _glsl->resetVertexAndFragment(vertPath.UTF8String, shaderString.UTF8String);
    
}
-(void)renderCVImageBuffer:(CVPixelBufferRef )pixelBuf normalsFaceBounds:(NSArray *)bounds{
    @autoreleasepool {
        size_t frameWidth = CVPixelBufferGetWidth(pixelBuf);
        size_t frameHeight = CVPixelBufferGetHeight(pixelBuf);
        size_t bytes = CVPixelBufferGetBytesPerRow(pixelBuf);
        size_t len = CVPixelBufferGetDataSize(pixelBuf);
        CVPixelBufferLockBaseAddress(pixelBuf, 0);
        void *data = CVPixelBufferGetBaseAddress(pixelBuf);
        
        if (data) {
            glBindTexture(GL_TEXTURE_2D, _textureID);
            glTexImage2D(GL_TEXTURE_2D, 0,
                         GL_RGBA,
                         bytes/4, len/bytes, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, data);
            CVPixelBufferUnlockBaseAddress(pixelBuf,0);

            glGenerateMipmap(GL_TEXTURE_2D);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            

            glBindFramebuffer(GL_FRAMEBUFFER,_fbo);
            glBindRenderbuffer(GL_RENDERBUFFER, _rbo);
            
            glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            
            float scale = [UIScreen mainScreen].scale;
            glViewport(0, 0, self.frame.size.width * scale, self.frame.size.height * scale);
           
            
            _glsl->use();
            glm::vec2 faces[8];
            memset(faces, 0, sizeof(faces));
            for (int i = 0; i < 4; i++) {
                if (i < bounds.count) {
                    NSValue *value = bounds[i];
                    CGRect rect = value.CGRectValue;
                    faces[2*i] = glm::vec2(rect.origin.x, rect.origin.y);
                    faces[2*i + 1] = glm::vec2(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
                }
                NSString *name = [NSString stringWithFormat:@"faceBounds[%d]",2*i];
                _glsl->setVec2(name.UTF8String, faces[2*i]);
                name = [NSString stringWithFormat:@"faceBounds[%d]",(2*i+1)];
                _glsl->setVec2(name.UTF8String, faces[2*i + 1]);
            }
            _glsl->setInt("faces", bounds.count);

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, _textureID);
            _glsl->setInt("tex", 0);
            
            
            glBindVertexArray(_VAO);
            glDrawArrays(GL_TRIANGLES, 0, 6);
            
            [_context presentRenderbuffer:GL_RENDERBUFFER];
            
            glBindTexture(GL_TEXTURE_2D, 0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glBindVertexArray(0);

           
            
            glBindRenderbuffer(GL_RENDERBUFFER, 0);
            glBindFramebuffer(GL_FRAMEBUFFER,0);
            
            
            
        }else{
            CVPixelBufferUnlockBaseAddress(pixelBuf,0);
        }
    }
}


unsigned int loadTexture(char const *path)
{
    unsigned int textureID;
    glGenTextures(1, &textureID);

    int width, height, nrComponents;
    unsigned char *data = stbi_load(path, &width, &height, &nrComponents, 0);
    if (data)
    {
        GLenum format = GL_RGB ;
        if (nrComponents == 1)
            format = GL_RED;
        else if (nrComponents == 3)
            format = GL_RGB;
        else if (nrComponents == 4)
            format = GL_RGBA;

        glBindTexture(GL_TEXTURE_2D, textureID);
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, data);
        glGenerateMipmap(GL_TEXTURE_2D);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        stbi_image_free(data);
    }
    else
    {
        std::cout << "Texture failed to load at path: " << path << std::endl;
        stbi_image_free(data);
    }

    return textureID;
}
@end
