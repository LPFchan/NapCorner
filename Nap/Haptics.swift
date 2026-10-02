import Foundation
import IOKit

/// A tap on the trackpad's Taptic Engine. AppKit's NSHapticFeedbackManager
/// only plays for the active app, so this drives the actuator through
/// MultitouchSupport directly, as HapticKey does
/// (https://github.com/niw/HapticKey). It's a private framework, loaded at
/// run time, so if it ever changes the tap just doesn't happen.
enum Haptics {
    private typealias Create = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    private typealias Call = @convention(c) (CFTypeRef) -> IOReturn
    private typealias Actuate = @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> IOReturn

    private static let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY)
    private static func symbol<T>(_ name: String, as: T.Type) -> T? {
        guard let lib, let sym = dlsym(lib, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    /// Taps every trackpad that has an actuator (built in or Magic
    /// Trackpad). `actuation` is one of MultitouchSupport's preset waveforms;
    /// 6 is the strongest.
    static func tap(_ actuation: Int32 = 6) {
        guard let create = symbol("MTActuatorCreateFromDeviceID", as: Create.self),
              let open = symbol("MTActuatorOpen", as: Call.self),
              let close = symbol("MTActuatorClose", as: Call.self),
              let actuate = symbol("MTActuatorActuate", as: Actuate.self) else { return }
        for id in trackpadIDs {
            guard let actuator = create(id)?.takeRetainedValue() else { continue }
            guard open(actuator) == kIOReturnSuccess else { continue }
            _ = actuate(actuator, actuation, 0, 0, 0)
            _ = close(actuator)
        }
    }

    /// The Multitouch IDs of trackpads whose actuator can be driven.
    private static var trackpadIDs: [UInt64] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"),
                                           &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var ids: [UInt64] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            guard (property("ActuationSupported") as? Bool) == true,
                  let id = property("Multitouch ID") as? NSNumber else { continue }
            ids.append(id.uint64Value)
        }
        return ids
    }
}
