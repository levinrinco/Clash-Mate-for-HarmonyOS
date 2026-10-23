package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"io"
	"os"
	"path/filepath"
	"sync"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"
)

var (
	mu        sync.Mutex
	lastError string
	logFile   *os.File
)

var logPathOverride string

//export BridgeSetLogPath
func BridgeSetLogPath(path *C.char) C.int {
	logPathOverride = C.GoString(path)
	return 0
}

func logPath() string {
	if logPathOverride != "" {
		return logPathOverride
	}
	return filepath.Join(constant.Path.HomeDir(), "mihomo.log")
}

func setupLog(level string) {
	file, err := os.OpenFile(logPath(), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err == nil {
		logFile = file
		logrus.SetOutput(io.MultiWriter(file))
		logrus.SetFormatter(&logrus.TextFormatter{DisableColors: true, FullTimestamp: true})
	}
	switch level {
	case "debug":
		logrus.SetLevel(logrus.DebugLevel)
	case "warning":
		logrus.SetLevel(logrus.WarnLevel)
	case "error":
		logrus.SetLevel(logrus.ErrorLevel)
	case "silent":
		logrus.SetLevel(logrus.PanicLevel)
	default:
		logrus.SetLevel(logrus.InfoLevel)
	}
}

//export BridgeLogTail
func BridgeLogTail() *C.char {
	data, err := os.ReadFile(logPath())
	if err != nil {
		return C.CString("")
	}
	const limit = 8000
	if len(data) > limit {
		data = data[len(data)-limit:]
	}
	return C.CString(string(data))
}

//export BridgeVersion
func BridgeVersion() *C.char {
	return C.CString(constant.Version)
}

//export BridgeSetHomeDir
func BridgeSetHomeDir(dir *C.char) C.int {
	constant.SetHomeDir(C.GoString(dir))
	return 0
}

//export BridgeValidate
func BridgeValidate(config *C.char) *C.char {
	if _, err := executor.ParseWithBytes([]byte(C.GoString(config))); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export BridgeStart
func BridgeStart(config *C.char, tunFd C.int, mode *C.char, logLevel *C.char, stack *C.char, mtu C.int) C.int {
	mu.Lock()
	defer mu.Unlock()

	var doc map[string]interface{}
	if err := yaml.Unmarshal([]byte(C.GoString(config)), &doc); err != nil {
		lastError = "yaml: " + err.Error()
		return -2
	}

	// mips 是纯 Go 用户态协议栈，不依赖 fstat 和内核回环监听；MTU 必须和 VPN 接口一致。
	stackName := C.GoString(stack)
	if stackName == "" {
		stackName = "mips"
	}
	tunMtu := int(mtu)
	if tunMtu <= 0 {
		tunMtu = 1500
	}
	doc["tun"] = map[string]interface{}{
		"enable":                true,
		"stack":                 stackName,
		"file-descriptor":       int(tunFd),
		"mtu":                   tunMtu,
		"dns-hijack":            []string{"any:53"},
		"auto-route":            false,
		"auto-detect-interface": false,
	}

	// IPv6 双栈：TUN 路由由鸿蒙侧配置，这里打开内核的 IPv6 解析与 DNS AAAA。
	doc["ipv6"] = true
	if dns, ok := doc["dns"].(map[string]interface{}); ok {
		dns["ipv6"] = true
		if mode, _ := dns["enhanced-mode"].(string); mode == "fake-ip" {
			if value, _ := dns["fake-ip-range6"].(string); value == "" {
				// 避开 TUN/DNS 所在的 fdfe:dcba:9876::/126，单独划一个 fake-ip6 段。
				dns["fake-ip-range6"] = "fdfe:dcba:9876:1::/64"
			}
		}
	}

	if value := C.GoString(mode); value != "" {
		doc["mode"] = value
	}
	if value := C.GoString(logLevel); value != "" {
		doc["log-level"] = value
	}

	merged, err := yaml.Marshal(doc)
	if err != nil {
		lastError = "marshal: " + err.Error()
		return -3
	}

	setupLog(C.GoString(logLevel))
	if err := hub.Parse(merged); err != nil {
		lastError = err.Error()
		return -1
	}
	lastError = ""
	return 0
}

//export BridgeStop
func BridgeStop() C.int {
	mu.Lock()
	defer mu.Unlock()

	executor.Shutdown()
	return 0
}

//export BridgeLastError
func BridgeLastError() *C.char {
	return C.CString(lastError)
}

func main() {}
