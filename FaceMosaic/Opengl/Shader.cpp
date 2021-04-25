//
//  Shader.cpp
//  iyinxiu
//
//  Created by JustinYang on 2021/3/18.
//  Copyright © 2021 yinxiu. All rights reserved.
//

#include "Shader.hpp"

using namespace std;
Shader::Shader(const char* vertexPath, const char* fragmentPath,const char* geometryPath){
    string vertexCode;
    string fragmentCode;
    string geometryCode;
    ifstream vShaderFile;
    ifstream fShaderFile;
    ifstream gShaderFile;
    
    vShaderFile.exceptions(ifstream::failbit | ifstream::badbit);
    fShaderFile.exceptions(ifstream::failbit | ifstream::badbit);
    gShaderFile.exceptions(ifstream::failbit | ifstream::badbit);
    
    try {
        vShaderFile.open(vertexPath);
        fShaderFile.open(fragmentPath);
        std::stringstream vShaderStream, fShaderStream;
        vShaderStream << vShaderFile.rdbuf();
        fShaderStream << fShaderFile.rdbuf();
        vShaderFile.close();
        fShaderFile.close();
        
        vertexCode = vShaderStream.str();
        fragmentCode = fShaderStream.str();
        
//        if (geometryPath != nullptr) {
//            gShaderFile.open(geometryPath);
//            std::stringstream gShaderStream;
//            gShaderStream << gShaderFile.rdbuf();
//            gShaderFile.close();
//            geometryCode = gShaderStream.str();
//        }
    } catch (std::ifstream::failure e ) {
        std::cout << "ERROR::shader::file_not_succesfully_read" << std::endl;
    }
    complierShader(vertexCode, fragmentCode);
  
    
}
void Shader::resetVertexAndFragment(const GLchar *vetexStrOrPath, const GLchar *fragmentStrOrPath){
  
    string vertexCode;
    string fragmentCode;
    string geometryCode;
    ifstream vShaderFile;
    ifstream fShaderFile;
    ifstream gShaderFile;
    
    vShaderFile.exceptions(ifstream::failbit | ifstream::badbit);
    fShaderFile.exceptions(ifstream::failbit | ifstream::badbit);
    
    try {
        vShaderFile.open(vetexStrOrPath);
        std::stringstream vShaderStream;
        vShaderStream << vShaderFile.rdbuf();
        vShaderFile.close();
        vertexCode = vShaderStream.str();
    } catch (std::ifstream::failure e ) {
        std::cout << "vetexString 不是一个路径，把他当做字符串处理" << std::endl;
        vertexCode = string(vetexStrOrPath);
    }
    
    try {
        fShaderFile.open(fragmentStrOrPath);
        std::stringstream  fShaderStream;
        fShaderStream << fShaderFile.rdbuf();
        fShaderFile.close();
        
        fragmentCode = fShaderStream.str();
        
    } catch (std::ifstream::failure e ) {
        std::cout << "fragmentString 不是一个路径，把他当做字符串处理" << std::endl;
        fragmentCode = string(fragmentStrOrPath);
    }
    
    complierShader(vertexCode, fragmentCode);
    
}
void Shader::complierShader(const string vertexString, const string fragmentString){
    const char * vShderCode = vertexString.c_str();
    const char * fShaderCode = fragmentString.c_str();
    if (ID != 0) {
        glDeleteProgram(ID);
        ID = 0;
    }
    //编译shader
    unsigned int vertex, fragment;
    vertex = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertex,1,&vShderCode, NULL);
    glCompileShader(vertex);
    checkCompileErrors(vertex, "VERTEX");
    
    fragment = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragment,1, &fShaderCode, NULL);
    glCompileShader(fragment);
    checkCompileErrors(fragment, "FRAGMENT");
    
    
    ID = glCreateProgram();
    glAttachShader(ID, vertex);
    glAttachShader(ID, fragment);

    glLinkProgram(ID);
    checkCompileErrors(ID, "PROGRAM");
    glDeleteShader(vertex);
    glDeleteShader(fragment);
}
void Shader::checkCompileErrors(GLuint shader, std::string type){
    GLint success;
    GLchar infoLog[1024];
    if (type != "PROGRAM") {
        glGetShaderiv(shader,GL_COMPILE_STATUS, &success);
        if (!success) {
            glGetShaderInfoLog(shader, 1024, NULL, infoLog);
            std::cout << "ERROR::SHADER_COMPILATION_ERROR of type: " << type << "\n" << infoLog << "\n -- --------------------------------------------------- -- " << std::endl;
        }
    }else{
        glGetProgramiv(shader, GL_LINK_STATUS, &success);
        if (!success) {
            glGetProgramInfoLog(shader,1024, NULL, infoLog);
            std::cout << "ERROR::PROGRAM_LINKING_ERROR of type: " << type << "\n" << infoLog << "\n -- --------------------------------------------------- -- " << std::endl;
        }
    }
}

void Shader::use(){
    glUseProgram(ID);
}

void Shader::setBool(const std::string &name, bool value) const{
    glUniform1i( glGetUniformLocation(ID,name.c_str()), (int)value);
}

void Shader::setInt(const std::string &name, int value) const{
    glUniform1i( glGetUniformLocation(ID,name.c_str()), value);
}


