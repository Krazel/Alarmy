import Capacitor
import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

@objc(AlarmKitNativePlugin)
public class AlarmKitNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AlarmKitNativePlugin"
    public let jsName = "AlarmKitNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isAvailable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestAuthorization", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "scheduleAlarm", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelAlarm", returnType: CAPPluginReturnPromise)
    ]

    @objc func isAvailable(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            call.resolve(["available": true])
        } else {
            call.resolve(["available": false, "reason": "AlarmKit requiere iOS 26 o superior."])
        }
        #else
        call.resolve(["available": false, "reason": "Este build no incluye el SDK de AlarmKit."])
        #endif
    }

    @objc func requestAuthorization(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task {
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    call.resolve(["authorized": isAuthorized(state)])
                } catch {
                    call.reject("No se pudo pedir permiso de AlarmKit.", nil, error)
                }
            }
        } else {
            call.resolve(["authorized": false])
        }
        #else
        call.resolve(["authorized": false])
        #endif
    }

    @objc func scheduleAlarm(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            guard let id = call.getString("id"),
                  let label = call.getString("label"),
                  let time = call.getString("time") else {
                call.reject("Faltan campos obligatorios para programar la alarma.")
                return
            }

            Task {
                do {
                    let authorized = try await ensureAuthorization()
                    guard authorized else {
                        call.resolve(["scheduled": false, "reason": "AlarmKit no autorizado."])
                        return
                    }

                    let schedule = makeSchedule(time: time, days: call.getArray("days", Int.self) ?? [])
                    let nativeId = UUID(uuidString: id) ?? UUID()
                    let presentation = AlarmPresentation(alert: AlarmPresentation.Alert(
                        title: LocalizedStringResource(stringLiteral: label),
                        stopButton: .stopButton,
                        secondaryButton: .snoozeButton,
                        secondaryButtonBehavior: .countdown
                    ))
                    let attributes = AlarmAttributes(
                        presentation: presentation,
                        metadata: AlarmyAlarmMetadata(label: label),
                        tintColor: .orange
                    )
                    let configuration = AlarmManager.AlarmConfiguration(
                        countdownDuration: nil,
                        schedule: schedule,
                        attributes: attributes
                    )

                    _ = try await AlarmManager.shared.schedule(id: nativeId, configuration: configuration)
                    call.resolve(["scheduled": true, "nativeId": nativeId.uuidString])
                } catch {
                    call.reject("No se pudo programar la alarma nativa.", nil, error)
                }
            }
        } else {
            call.resolve(["scheduled": false, "reason": "AlarmKit requiere iOS 26 o superior."])
        }
        #else
        call.resolve(["scheduled": false, "reason": "AlarmKit no disponible en este SDK."])
        #endif
    }

    @objc func cancelAlarm(_ call: CAPPluginCall) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            guard let id = call.getString("id") else {
                call.reject("Falta id de alarma.")
                return
            }

            Task {
                let nativeId = UUID(uuidString: id) ?? UUID()
                do {
                    try await AlarmManager.shared.cancel(id: nativeId)
                    call.resolve(["cancelled": true])
                } catch {
                    call.reject("No se pudo cancelar la alarma nativa.", nil, error)
                }
            }
        } else {
            call.resolve(["cancelled": false])
        }
        #else
        call.resolve(["cancelled": false])
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func ensureAuthorization() async throws -> Bool {
        let state = try await AlarmManager.shared.requestAuthorization()
        return isAuthorized(state)
    }

    @available(iOS 26.0, *)
    private func isAuthorized(_ state: AlarmManager.AuthorizationState) -> Bool {
        switch state {
        case .authorized:
            return true
        default:
            return false
        }
    }

    @available(iOS 26.0, *)
    private func makeSchedule(time: String, days: [Int]) -> Alarm.Schedule {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let hour = parts.indices.contains(0) ? parts[0] : 7
        let minute = parts.indices.contains(1) ? parts[1] : 30
        let alarmTime = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let weekdays = days.compactMap { weekday(from: $0) }
        let recurrence: Alarm.Schedule.Relative.Recurrence = weekdays.isEmpty ? .never : .weekly(weekdays)
        return .relative(.init(time: alarmTime, repeats: recurrence))
    }

    @available(iOS 26.0, *)
    private func weekday(from day: Int) -> Locale.Weekday? {
        switch day {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return nil
        }
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct AlarmyAlarmMetadata: AlarmMetadata {
    var label: String
}
#endif
