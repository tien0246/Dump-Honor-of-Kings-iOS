#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#import <substrate.h>
#include <sys/sysctl.h>

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;

#define timer(sec) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, sec * NSEC_PER_SEC), dispatch_get_main_queue(), ^

// Credit KittyMemory
class MemoryInfo {
   public:
    uint32_t index;
    const mach_header *header;
    const char *name;
    intptr_t address;
};

// Credit KittyMemory
MemoryInfo getBaseAddress(const string &fileName) {
    MemoryInfo _info;

    const uint32_t imageCount = _dyld_image_count();

    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name)
            continue;

        string fullpath(name);

        if (fullpath.length() < fileName.length() || fullpath.compare(fullpath.length() - fileName.length(), fileName.length(), fileName) != 0)
            continue;

        _info.index = i;
        _info.header = _dyld_get_image_header(i);
        _info.name = _dyld_get_image_name(i);
        _info.address = _dyld_get_image_vmaddr_slide(i);

        break;
    }
    return _info;
}

MemoryInfo info;

struct Il2CppClass {
    const char *name;
    const char *namespace_;

    Il2CppClass(const char *name, const char *namespace_)
        : name(name), namespace_(namespace_) {}
};

struct Il2CppImage {
    const char *name;
    size_t class_count;
    Il2CppClass **classes;

    Il2CppImage(const char *name, size_t class_count, Il2CppClass **classes)
        : name(name), class_count(class_count), classes(classes) {}
};

struct Il2CppType {
    int type;
    int attrs;

    Il2CppType(int t, int a) : type(t), attrs(a) {}
};

struct Il2CppOffset {
    intptr_t il2cpp_assembly_get_image;
    intptr_t il2cpp_domain_get;
    intptr_t il2cpp_domain_get_assemblies;
    intptr_t il2cpp_image_get_name;
    intptr_t il2cpp_class_from_name;
    intptr_t il2cpp_class_get_methods;
    intptr_t il2cpp_class_get_fields;
    intptr_t il2cpp_class_get_name;
    intptr_t il2cpp_class_get_namespace;
    intptr_t il2cpp_method_get_name;
    intptr_t il2cpp_field_get_name;
    intptr_t il2cpp_field_get_type;
    intptr_t il2cpp_field_get_offset;
    intptr_t il2cpp_field_static_get_value;
    intptr_t il2cpp_field_static_set_value;
    intptr_t il2cpp_string_new;
    intptr_t il2cpp_string_new_utf16;
    intptr_t il2cpp_string_chars;
    intptr_t il2cpp_type_get_name;
    intptr_t il2cpp_method_get_param;
    intptr_t il2cpp_class_get_method_from_name;
    intptr_t il2cpp_class_get_field_from_name;
    intptr_t il2cpp_image_get_class_count;
    intptr_t il2cpp_image_get_class;
    intptr_t il2cpp_method_get_param_count;
    intptr_t il2cpp_method_get_return_type;
    intptr_t il2cpp_class_from_type;
};

namespace IL2CPP {
    const void *(*il2cpp_assembly_get_image)(const void *assembly);
    void *(*il2cpp_domain_get)();
    void **(il2cpp_domain_get_assemblies)(const void *domain, size_t *size);
    const char *(il2cpp_image_get_name)(void *image);
    void *(*il2cpp_class_from_name)(const void *image, const char *namespaze, const char *name);
    const char *(*il2cpp_class_get_name)(void *klass);
    const char *(*il2cpp_class_get_namespace)(void *klass);
    void *(*il2cpp_class_get_methods)(void *klass, void **iter);
    void *(il2cpp_class_get_fields)(void *klass, void **iter);
    const char *(*il2cpp_method_get_name)(void *method);
    const char *(il2cpp_field_get_name)(void *field);
    Il2CppType *(*il2cpp_field_get_type)(void *field);
    size_t (*il2cpp_field_get_offset)(void *field);
    void (*il2cpp_field_static_get_value)(void *field, void *value);
    void (*il2cpp_field_static_set_value)(void *field, void *value);

    void *(*il2cpp_string_new)(const char *str);
    void *(*il2cpp_string_new_utf16)(const wchar_t *str, int32_t length);
    uint16_t *(*il2cpp_string_chars)(void *str);

    char *(*il2cpp_type_get_name)(void *type);
    void *(*il2cpp_method_get_param)(void *method, uint32_t index);

    void *(*il2cpp_class_get_method_from_name)(void *klass, const char *name, int argsCount);
    void *(*il2cpp_class_get_field_from_name)(void *klass, const char *name);

    size_t (il2cpp_image_get_class_count)(const Il2CppImage *image);
    Il2CppClass *(il2cpp_image_get_class)(const Il2CppImage *image, size_t index);

    int32_t (*il2cpp_method_get_param_count)(void *method);
    void *(*il2cpp_method_get_return_type)(void *method);
    void *(*il2cpp_class_from_type)(void *type);
}  // namespace IL2CPP

void **IL2CPP::il2cpp_domain_get_assemblies(const void *domain, size_t *size) {
    void **global_assembly = (void **)(info.address + (intptr_t)0x10C027318);
    *size = (*(uint64_t*)(global_assembly + 1) - (uint64_t)*global_assembly) >> 3;
    return *(void ***)global_assembly;
}

const char* IL2CPP::il2cpp_image_get_name(void* a1) {
    return *reinterpret_cast<const char**>(a1);
}

void* IL2CPP::il2cpp_class_get_fields(void* klass, void** iter) {
    if (!iter) {
        return nullptr;
    }

    auto v4 = *reinterpret_cast<uintptr_t*>(iter);

    if (v4) {
        auto result = v4 + 0x28;

        if (*reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(klass) + 104) +
            40 * static_cast<uintptr_t>(*reinterpret_cast<uint16_t*>(reinterpret_cast<uintptr_t>(klass) + 264)) > result) {
            *reinterpret_cast<uintptr_t*>(iter) = result;
            return reinterpret_cast<void*>(result);
        }
    } else {
        void (*sub_10971F2AC)(void*) = reinterpret_cast<void (*)(void*)>(info.address + 0x10971F2AC);
        sub_10971F2AC(klass);
        if (*reinterpret_cast<uint16_t*>(reinterpret_cast<uintptr_t>(klass) + 264)) {
            *reinterpret_cast<uintptr_t*>(iter) = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(klass) + 104);
            return reinterpret_cast<void*>(*reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(klass) + 104));
        }
    }
    return nullptr;
}


const char* IL2CPP::il2cpp_field_get_name(void* field) {
    return *reinterpret_cast<const char**>(field);
}

size_t IL2CPP::il2cpp_image_get_class_count(const Il2CppImage* image) {
    return *(int32_t*)((uintptr_t)image + 0x10);
}

Il2CppClass *IL2CPP::il2cpp_image_get_class(const Il2CppImage *image, size_t index) {
    int32_t typeDefinitionIndex = *reinterpret_cast<int32_t*>(reinterpret_cast<uintptr_t>(image) + 0xc) + index;
    Il2CppClass* (*GetTypeInfoFromTypeDefinitionIndex)(int32_t) = reinterpret_cast<Il2CppClass* (*)(int32_t)>(info.address + 0x10972CD70);
    return GetTypeInfoFromTypeDefinitionIndex(typeDefinitionIndex);
}


void Il2CppAttach() {
    info = getBaseAddress("sgameGlobal");

    Il2CppOffset il2cppoffset;

    il2cppoffset.il2cpp_assembly_get_image = info.address + (intptr_t) 0x1096EA024;
    il2cppoffset.il2cpp_domain_get = info.address + (intptr_t) 0x1096EA160;
    // // il2cppoffset.il2cpp_domain_get_assemblies = info.address + (intptr_t) ;
    // // il2cppoffset.il2cpp_image_get_name = info.address + (intptr_t) ;
    il2cppoffset.il2cpp_class_from_name = info.address + (intptr_t) 0x1096EA044;
    il2cppoffset.il2cpp_class_get_methods = info.address + (intptr_t) 0x1096EA054;
    // il2cppoffset.il2cpp_class_get_fields = info.address + (intptr_t) ;
    il2cppoffset.il2cpp_class_get_name = info.address + (intptr_t) 0x1096EA058;
    il2cppoffset.il2cpp_class_get_namespace = info.address + (intptr_t) 0x1096EA05C;
    il2cppoffset.il2cpp_method_get_name = info.address + (intptr_t) 0x1096EA1C8;
    // il2cppoffset.il2cpp_field_get_name = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_field_get_type = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_field_get_offset = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_field_static_get_value = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_field_static_set_value = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_string_new = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_string_new_utf16 = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_string_chars = info.address + (intptr_t) ;
    il2cppoffset.il2cpp_type_get_name = info.address + (intptr_t) 0x1096EA2EC;
    il2cppoffset.il2cpp_method_get_param = info.address + (intptr_t) 0x1096EA1DC;
    il2cppoffset.il2cpp_class_get_method_from_name = info.address + (intptr_t) 0x10971F670;
    // il2cppoffset.il2cpp_class_get_field_from_name = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_image_get_class_count = info.address + (intptr_t) ;
    // il2cppoffset.il2cpp_image_get_class = info.address + (intptr_t) ;
    il2cppoffset.il2cpp_method_get_param_count = info.address + (intptr_t) 0x1096EA1D8;
    il2cppoffset.il2cpp_method_get_return_type = info.address + (intptr_t) 0x1096EA1C0;
    il2cppoffset.il2cpp_class_from_type = info.address + (intptr_t) 0x1096EA080;

    IL2CPP::il2cpp_assembly_get_image = reinterpret_cast<const void *(*)(const void *)>(il2cppoffset.il2cpp_assembly_get_image);
    IL2CPP::il2cpp_domain_get = reinterpret_cast<void *(*)()>(il2cppoffset.il2cpp_domain_get);
    // IL2CPP::il2cpp_domain_get_assemblies = reinterpret_cast<void **(*)(const void *, size_t *)>(il2cppoffset.il2cpp_domain_get_assemblies);
    // IL2CPP::il2cpp_image_get_name = reinterpret_cast<const char *(*)(void *)>(il2cppoffset.il2cpp_image_get_name);
    IL2CPP::il2cpp_class_from_name = reinterpret_cast<void *(*)(const void *, const char *, const char *)>(il2cppoffset.il2cpp_class_from_name);
    IL2CPP::il2cpp_class_get_methods = reinterpret_cast<void *(*)(void *, void **)>(il2cppoffset.il2cpp_class_get_methods);
    // IL2CPP::il2cpp_class_get_fields = reinterpret_cast<void *(*)(void *, void **)>(il2cppoffset.il2cpp_class_get_fields);
    IL2CPP::il2cpp_class_get_name = reinterpret_cast<const char *(*)(void *)>(il2cppoffset.il2cpp_class_get_name);
    IL2CPP::il2cpp_class_get_namespace = reinterpret_cast<const char *(*)(void *)>(il2cppoffset.il2cpp_class_get_namespace);
    IL2CPP::il2cpp_method_get_name = reinterpret_cast<const char *(*)(void *)>(il2cppoffset.il2cpp_method_get_name);
    // IL2CPP::il2cpp_field_get_name = reinterpret_cast<const char *(*)(void *)>(il2cppoffset.il2cpp_field_get_name);
    IL2CPP::il2cpp_field_get_type = reinterpret_cast<Il2CppType *(*)(void *)>(il2cppoffset.il2cpp_field_get_type);
    IL2CPP::il2cpp_field_get_offset = reinterpret_cast<size_t (*)(void *)>(il2cppoffset.il2cpp_field_get_offset);
    IL2CPP::il2cpp_field_static_get_value = reinterpret_cast<void (*)(void *, void *)>(il2cppoffset.il2cpp_field_static_get_value);
    IL2CPP::il2cpp_field_static_set_value = reinterpret_cast<void (*)(void *, void *)>(il2cppoffset.il2cpp_field_static_set_value);

    IL2CPP::il2cpp_string_new = reinterpret_cast<void *(*)(const char *)>(il2cppoffset.il2cpp_string_new);
    IL2CPP::il2cpp_string_new_utf16 = reinterpret_cast<void *(*)(const wchar_t *, int32_t)>(il2cppoffset.il2cpp_string_new_utf16);
    IL2CPP::il2cpp_string_chars = reinterpret_cast<uint16_t *(*)(void *)>(il2cppoffset.il2cpp_string_chars);

    IL2CPP::il2cpp_type_get_name = reinterpret_cast<char *(*)(void *)>(il2cppoffset.il2cpp_type_get_name);
    IL2CPP::il2cpp_method_get_param = reinterpret_cast<void *(*)(void *, uint32_t)>(il2cppoffset.il2cpp_method_get_param);

    IL2CPP::il2cpp_class_get_method_from_name = reinterpret_cast<void *(*)(void *, const char *, int)>(il2cppoffset.il2cpp_class_get_method_from_name);
    IL2CPP::il2cpp_class_get_field_from_name = reinterpret_cast<void *(*)(void *, const char *)>(il2cppoffset.il2cpp_class_get_field_from_name);

    // IL2CPP::il2cpp_image_get_class_count = reinterpret_cast<size_t (*)(const Il2CppImage *)>(il2cppoffset.il2cpp_image_get_class_count);
    // IL2CPP::il2cpp_image_get_class = reinterpret_cast<Il2CppClass *(*)(const Il2CppImage *, size_t)>(il2cppoffset.il2cpp_image_get_class);

    IL2CPP::il2cpp_method_get_param_count = reinterpret_cast<int32_t (*)(void *)>(il2cppoffset.il2cpp_method_get_param_count);
    IL2CPP::il2cpp_method_get_return_type = reinterpret_cast<void *(*)(void *)>(il2cppoffset.il2cpp_method_get_return_type);
    IL2CPP::il2cpp_class_from_type = reinterpret_cast<void *(*)(void *)>(il2cppoffset.il2cpp_class_from_type);

}

void *Il2CppGetImageByName(const char *image) {
    size_t size;
    void **assemblies = IL2CPP::il2cpp_domain_get_assemblies(IL2CPP::il2cpp_domain_get(), &size);
    for (size_t i = 0; i < size; ++i) {
        void *img = (void *)IL2CPP::il2cpp_assembly_get_image(assemblies[i]);
        const char *img_name = IL2CPP::il2cpp_image_get_name(img);
        if (strcmp(img_name, image) == 0) {
            return img;
        }
    }
    return nullptr;
}

class Il2CppString {
   private:
    void *str;

   public:
    // Constructors
    Il2CppString(const char *utf8Str) {
        str = IL2CPP::il2cpp_string_new(utf8Str);
    }

    Il2CppString(const wchar_t *utf16Str, int32_t length) {
        str = IL2CPP::il2cpp_string_new_utf16(utf16Str, length);
    }

    // Destructor
    ~Il2CppString() {
        // Release IL2CPP string if needed
    }

    // Get characters from the IL2CPP string
    uint16_t *getChars() {
        return IL2CPP::il2cpp_string_chars(str);
    }

    // Convert IL2CPP string to UTF-8
    string toUtf8String() {
        uint16_t *chars = getChars();
        if (!chars) {
            return "";
        }

        string utf8Str;
        for (int i = 0; chars[i] != '\0'; ++i) {
            utf8Str += static_cast<char>(chars[i]);
        }
        return utf8Str;
    }

    // Convert IL2CPP string to UTF-16
    wstring toUtf16String() {
        uint16_t *chars = getChars();
        if (!chars) {
            return L"";
        }

        wstring utf16Str;
        for (int i = 0; chars[i] != '\0'; ++i) {
            utf16Str += static_cast<wchar_t>(chars[i]);
        }
        return utf16Str;
    }

    // Get internal IL2CPP string pointer (if needed)
    void *getInternalString() {
        return str;
    }
};

class Il2CppField {
   private:
    void *image;
    void *klass;
    void *field;

   public:
    // Constructor initializes the image from assembly name
    Il2CppField(const char *assemblyName) {
        image = Il2CppGetImageByName(assemblyName);
        if (!image) {
            //[menu showPopup:@"Error" description:@"Cannot find specified image."];
            NSLog(@"Error: Cannot find specified image.");
        }
    }

    // Get class by namespace and class name
    Il2CppField &getClass(const char *namespaze, const char *className) {
        klass = IL2CPP::il2cpp_class_from_name(image, namespaze, className);
        if (!klass) {
            //[menu showPopup:@"Error" description:[NSString stringWithFormat:@"Cannot find class %s in namespace %s.", className, namespaze]];
            NSLog(@"Error: Cannot find class %s in namespace %s.", className, namespaze);
        }
        return *this;
    }

    // Get field by field name
    Il2CppField &getField(const char *fieldName) {
        field = IL2CPP::il2cpp_class_get_field_from_name(klass, fieldName);
        if (!field) {
            //[menu showPopup:@"Error" description:[NSString stringWithFormat:@"Cannot find field %s in class.", fieldName]];
            NSLog(@"Error: Cannot find field %s in class.", fieldName);
        }
        return *this;
    }

    // Get field offset
    size_t getOffset() const {
        return IL2CPP::il2cpp_field_get_offset(field);
    }

    // Get field value
    template <typename T>
    T getValue() {
        T value;
        IL2CPP::il2cpp_field_static_get_value(field, &value);
        return value;
    }

    // Set field value
    template <typename T>
    void setValue(T value) {
        IL2CPP::il2cpp_field_static_set_value(field, &value);
    }

    // Show field value using menu popup
    template <typename T>
    void showValue(const char *fieldName) {
        T value = getValue<T>();
        // NSString* message = [NSString stringWithFormat:@"%s Value = %d", fieldName, value];
        // [menu showPopup:@"Field Value" description:message];
        NSLog(@"%s Value = %d", fieldName, value);
    }
};

class Il2CppMethod {
   private:
    void *image;
    void *klass;
    void *method;

   public:
    // Constructor initializes the image from assembly name
    Il2CppMethod(const char *assemblyName) {
        image = Il2CppGetImageByName(assemblyName);
        if (!image) {
            //[menu showPopup:@"Error" description:@"Cannot find specified image."];
            NSLog(@"Error: Cannot find specified image.");
        }
    }

    // Get class by namespace and class name
    Il2CppMethod &getClass(const char *namespaze, const char *className) {
        klass = IL2CPP::il2cpp_class_from_name(image, namespaze, className);
        if (!klass) {
            NSLog(@"Error: Cannot find class %s in namespace %s.", className, namespaze);
        }
        return *this;
    }

    // Get method by method name and number of arguments
    uint64_t getMethod(const char *methodName, int argsCount) {
        void **methodPointer = (void **)IL2CPP::il2cpp_class_get_method_from_name(klass, methodName, argsCount);
        if (!methodPointer || !*methodPointer) {
            NSLog(@"Error: Cannot find method %s with %d arguments.", methodName, argsCount);
            return 0;
        }
        method = *methodPointer;

        uint64_t rvaOffset = reinterpret_cast<uint64_t>(method) - info.address;

        return rvaOffset;
    }

    // Invoke the method with given arguments
    template <typename Ret, typename... Args>
    Ret invoke(Args... args) {
        using MethodType = Ret (*)(Args...);
        MethodType methodFunc = reinterpret_cast<MethodType>(method);
        return methodFunc(args...);
    }
};

class Il2CppInspector {
   private:
    void *domain;
    string appPath;
    string filePath;

   public:
    Il2CppInspector() {
        domain = IL2CPP::il2cpp_domain_get();
        NSString *nsDocPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        string docPath = [nsDocPath UTF8String];
        filePath = docPath + "/il2cpp_info.txt";
    }

    vector<void *> getAssemblies() {
        size_t size;
        void **assemblies = IL2CPP::il2cpp_domain_get_assemblies(domain, &size);
        return vector<void *>(assemblies, assemblies + size);
    }

    vector<void *> getClasses(void *image) {
        vector<void *> classes;
        const Il2CppImage *il2cppImage = static_cast<Il2CppImage *>(image);
        size_t classCount = IL2CPP::il2cpp_image_get_class_count(il2cppImage);
        for (size_t i = 0; i < classCount; ++i) {
            classes.push_back(IL2CPP::il2cpp_image_get_class(il2cppImage, i));
        }
        return classes;
    }

    vector<void *> getMethods(void *klass) {
        vector<void *> methods;
        void *iter = nullptr;
        void *method = nullptr;

        while ((method = IL2CPP::il2cpp_class_get_methods(klass, &iter)) != nullptr) {
            methods.push_back(method);
        }
        return methods;
    }

    vector<void *> getFields(void *klass) {
        vector<void *> fields;
        void *iter = nullptr;
        void *field = nullptr;

        while ((field = IL2CPP::il2cpp_class_get_fields(klass, &iter)) != nullptr) {
            fields.push_back(field);
        }
        return fields;
    }

    string dump() {
        stringstream ss;

        ss << "----Il2cpp Theo Dumper by Batchh v0.1----n\n";

        auto assemblies = getAssemblies();
        for (auto assembly : assemblies) {
            const void *image = IL2CPP::il2cpp_assembly_get_image(assembly);
            NSLog(@"%p", image);
            const char *imageName = IL2CPP::il2cpp_image_get_name((void *)image);
            // NSLog(@"%s", imageName);
            ss << "DLL: " << imageName << "\n";
            auto classes = getClasses((void *)image);
            for (auto klass : classes) {
                const char *className = IL2CPP::il2cpp_class_get_name(klass);
                // NSLog(@"%s", className);
                const char *classNamespace = IL2CPP::il2cpp_class_get_namespace(klass);
                if (classNamespace) {
                    ss << "  Class: " << classNamespace << "." << className << "\n";
                } else {
                    ss << "  Class: " << className << "\n";
                }

                auto methods = getMethods(klass);
                for (auto method : methods) {
                    const char *methodName = IL2CPP::il2cpp_method_get_name(method);
                    // NSLog(@"%s", methodName);

                    const char *returnType = "void";
                    void *returnTypeObj = IL2CPP::il2cpp_method_get_return_type(method);
                    if (returnTypeObj != nullptr) {
                        returnType = IL2CPP::il2cpp_type_get_name(returnTypeObj);
                    }

                    ss << "    Method: " << returnType << " " << methodName << "(";

                    int32_t paramCount = IL2CPP::il2cpp_method_get_param_count(method);
                    for (int32_t j = 0; j < paramCount; ++j) {
                        void *paramType = IL2CPP::il2cpp_method_get_param(method, j);
                        if (paramType) {
                            void *parameter_class = IL2CPP::il2cpp_class_from_type(paramType);
                            const char *parameter_class_name = IL2CPP::il2cpp_class_get_name(parameter_class);
                            ss << parameter_class_name;
                            if (j < paramCount - 1)
                                ss << ", ";
                        }
                    }
                    void **methodPointer = (void **)IL2CPP::il2cpp_class_get_method_from_name(klass, methodName, paramCount);
                    method = *methodPointer;
                    uint64_t rvaOffset = reinterpret_cast<uint64_t>(method) - info.address;
                    ss << ") // RVA Offset: 0x" << hex << rvaOffset << "\n";
                }

                auto fields = getFields(klass);
                for (auto field : fields) {
                    const char *fieldName = IL2CPP::il2cpp_field_get_name(field);
                    Il2CppType *fieldType = IL2CPP::il2cpp_field_get_type(field);

                    void *field_class = IL2CPP::il2cpp_class_from_type(fieldType);
                    const char *fieldTypeName = IL2CPP::il2cpp_class_get_name(field_class);

                    size_t offset = IL2CPP::il2cpp_field_get_offset(field);

                    ss << "    Field: " << fieldTypeName << " " << fieldName << " // 0x" << offset << "\n";
                }
            }
            ss << "\n";
        }

        return ss.str();
    }

    void shareAssemblyInfo() {
        string assemblyInfo = dump();

        NSString *nsFilePath = [NSString stringWithUTF8String:filePath.c_str()];
        NSString *nsAssemblyInfo = [NSString stringWithUTF8String:assemblyInfo.c_str()];

        NSError *error = nil;
        BOOL success = [nsAssemblyInfo writeToFile:nsFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;

            if (!success) {
                NSLog(@"Failed to write to file: %@", error);
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                            message:@"Failed to dump."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                                style:UIAlertActionStyleDefault
                                                                handler:nil];
                [alert addAction:okAction];
                [rootViewController presentViewController:alert animated:YES completion:nil];
                return;
            }
            UIAlertController *completionAlert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                                    message:@"Dump successfully."
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                            handler:nil];
            [completionAlert addAction:okAction];
            [rootViewController presentViewController:completionAlert animated:YES completion:nil];
        });
    }
};

%ctor {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        sleep(30);
        NSLog(@"=================STRAT DUMPPER=================");
        Il2CppAttach();
        Il2CppInspector inspector;
        inspector.shareAssemblyInfo();
        NSLog(@"=================END DUMPPER=================");
    });
}