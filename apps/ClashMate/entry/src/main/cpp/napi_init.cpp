#include <dlfcn.h>

#include <string>
#include <vector>

#include "napi/native_api.h"

namespace {

using VersionFn = const char* (*)();
using ValidateFn = const char* (*)(const char*);
using SetHomeFn = int (*)(const char*);
using LogTailFn = const char* (*)();
using SetLogPathFn = int (*)(const char*);
using StartFn = int (*)(const char*, int, const char*, const char*, const char*, int);
using StopFn = int (*)();
using LastErrorFn = const char* (*)();

void* g_lib = nullptr;
VersionFn g_version = nullptr;
ValidateFn g_validate = nullptr;
SetHomeFn g_setHome = nullptr;
LogTailFn g_logTail = nullptr;
SetLogPathFn g_setLogPath = nullptr;
StartFn g_start = nullptr;
StopFn g_stop = nullptr;
LastErrorFn g_lastError = nullptr;
std::string g_loadError;

bool Load() {
    if (g_lib != nullptr) {
        return g_version != nullptr && g_validate != nullptr && g_setHome != nullptr && g_logTail != nullptr &&
               g_setLogPath != nullptr && g_start != nullptr && g_stop != nullptr && g_lastError != nullptr;
    }
    void* lib = dlopen("libmihomo.so", RTLD_NOW | RTLD_LOCAL);
    if (lib == nullptr) {
        const char* err = dlerror();
        g_loadError = err == nullptr ? "dlopen failed" : err;
        return false;
    }
    g_version = reinterpret_cast<VersionFn>(dlsym(lib, "BridgeVersion"));
    g_validate = reinterpret_cast<ValidateFn>(dlsym(lib, "BridgeValidate"));
    g_setHome = reinterpret_cast<SetHomeFn>(dlsym(lib, "BridgeSetHomeDir"));
    g_logTail = reinterpret_cast<LogTailFn>(dlsym(lib, "BridgeLogTail"));
    g_setLogPath = reinterpret_cast<SetLogPathFn>(dlsym(lib, "BridgeSetLogPath"));
    g_start = reinterpret_cast<StartFn>(dlsym(lib, "BridgeStart"));
    g_stop = reinterpret_cast<StopFn>(dlsym(lib, "BridgeStop"));
    g_lastError = reinterpret_cast<LastErrorFn>(dlsym(lib, "BridgeLastError"));
    if (g_version == nullptr || g_validate == nullptr || g_setHome == nullptr || g_logTail == nullptr ||
        g_setLogPath == nullptr || g_start == nullptr || g_stop == nullptr || g_lastError == nullptr) {
        dlclose(lib);
        g_version = nullptr;
        g_validate = nullptr;
        g_setHome = nullptr;
        g_logTail = nullptr;
        g_setLogPath = nullptr;
        g_start = nullptr;
        g_stop = nullptr;
        g_lastError = nullptr;
        g_loadError = "dlsym failed";
        return false;
    }
    g_lib = lib;
    return true;
}

napi_value MakeString(napi_env env, const char* value) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, value == nullptr ? "" : value, NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value MakeInt(napi_env env, int value) {
    napi_value result = nullptr;
    napi_create_int32(env, value, &result);
    return result;
}

std::string ReadString(napi_env env, napi_value value) {
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);
    std::vector<char> buffer(length + 1, '\0');
    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &length);
    return std::string(buffer.data());
}

napi_value Version(napi_env env, napi_callback_info info) {
    if (!Load()) {
        return MakeString(env, g_loadError.c_str());
    }
    return MakeString(env, g_version());
}

napi_value Validate(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        return MakeString(env, "config required");
    }
    if (!Load()) {
        return MakeString(env, g_loadError.c_str());
    }
    return MakeString(env, g_validate(ReadString(env, argv[0]).c_str()));
}

napi_value SetHome(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        return MakeInt(env, -1);
    }
    if (!Load()) {
        return MakeInt(env, -99);
    }
    return MakeInt(env, g_setHome(ReadString(env, argv[0]).c_str()));
}

napi_value LogTail(napi_env env, napi_callback_info info) {
    if (!Load()) {
        return MakeString(env, g_loadError.c_str());
    }
    return MakeString(env, g_logTail());
}

napi_value SetLogPath(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        return MakeInt(env, -1);
    }
    if (!Load()) {
        return MakeInt(env, -99);
    }
    return MakeInt(env, g_setLogPath(ReadString(env, argv[0]).c_str()));
}

napi_value Start(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value argv[6] = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        return MakeInt(env, -1);
    }

    std::string config = ReadString(env, argv[0]);
    int32_t tunFd = -1;
    napi_get_value_int32(env, argv[1], &tunFd);
    std::string mode = argc > 2 ? ReadString(env, argv[2]) : "";
    std::string logLevel = argc > 3 ? ReadString(env, argv[3]) : "";
    std::string stack = argc > 4 ? ReadString(env, argv[4]) : "mips";
    int32_t mtu = 1500;
    if (argc > 5) {
        napi_get_value_int32(env, argv[5], &mtu);
    }

    if (!Load()) {
        return MakeInt(env, -99);
    }
    return MakeInt(env, g_start(config.c_str(), tunFd, mode.c_str(), logLevel.c_str(), stack.c_str(), mtu));
}

napi_value Stop(napi_env env, napi_callback_info info) {
    if (!Load()) {
        return MakeInt(env, -99);
    }
    return MakeInt(env, g_stop());
}

napi_value LastError(napi_env env, napi_callback_info info) {
    if (!Load()) {
        return MakeString(env, g_loadError.c_str());
    }
    return MakeString(env, g_lastError());
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"validate", nullptr, Validate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setHome", nullptr, SetHome, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"logTail", nullptr, LogTail, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setLogPath", nullptr, SetLogPath, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stop", nullptr, Stop, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"lastError", nullptr, LastError, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

}  // namespace

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&g_module);
}
