void simulateVolumeDown(void) {
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;

    IOHIDEventCreateKeyboardEvent_t createEvent = (IOHIDEventCreateKeyboardEvent_t)dlsym(handle, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSystemClientCreate_t createClient = (IOHIDEventSystemClientCreate_t)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent_t dispatchEvent = (IOHIDEventSystemClientDispatchEvent_t)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    IOHIDEventSetSenderID_t setSender = (IOHIDEventSetSenderID_t)dlsym(handle, "IOHIDEventSetSenderID");

    if (createEvent && createClient && dispatchEvent) {
        IOHIDEventSystemClientRef client = createClient(kCFAllocatorDefault);
        if (client) {
            // 1. 发送按下事件 (down = true)
            IOHIDEventRef downEvent = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0x0C, 0xEA, true, 0);
            if (downEvent) {
                if (setSender) setSender(downEvent, 0xDEFACEDBEEFFECE5); // 伪造一个合法的发送者ID
                dispatchEvent(client, downEvent);
                CFRelease(downEvent);
            }
            
            // 短暂延时，模拟真实按键的物理间隔
            usleep(50000); // 50毫秒

            // 2. 发送抬起事件 (down = false)
            IOHIDEventRef upEvent = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0x0C, 0xEA, false, 0);
            if (upEvent) {
                if (setSender) setSender(upEvent, 0xDEFACEDBEEFFECE5);
                dispatchEvent(client, upEvent);
                CFRelease(upEvent);
            }
            CFRelease(client);
        }
    }
    dlclose(handle);
}