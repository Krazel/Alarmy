#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(AlarmKitNativePlugin, "AlarmKitNative",
           CAP_PLUGIN_METHOD(isAvailable, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(requestAuthorization, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(scheduleAlarm, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(cancelAlarm, CAPPluginReturnPromise);
)
