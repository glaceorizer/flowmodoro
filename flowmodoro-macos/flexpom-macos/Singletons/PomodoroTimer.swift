import Foundation

class PomodoroTimer {
    static let shared = PomodoroTimer()
    
    private var timer: Timer?
    private var observations = [ObjectIdentifier: Observation]()
    
    // NEU: Speichert die exakte Uhrzeit des letzten Ticks
    private var lastTickDate: Date?
    
    private init() {}
    
    func start() {
        self.timer?.invalidate()
        self.lastTickDate = Date()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let lastTick = self.lastTickDate else { return }
            
            let now = Date()
            // Berechne die reale vergangene Zeit (z.B. 600 Sekunden nach dem Standby)
            let timeElapsed = Int(round(now.timeIntervalSince(lastTick)))
            
            // Nur ausführen, wenn mindestens 1 Sekunde vergangen ist
            if timeElapsed > 0 {
                self.lastTickDate = now
                
                for (id, observation) in self.observations {
                    // If the observer is no longer in memory, clean up
                    guard let observer = observation.observer else {
                        self.observations.removeValue(forKey: id)
                        continue
                    }
                    
                    // Übergebe die tatsächlich vergangene Zeit
                    observer.timerDidFire(self, timeElapsed: timeElapsed)
                }
            }
        }
    }
    
    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        self.lastTickDate = nil
    }
}


// MARK: - Observable

protocol TimerObserver: AnyObject {
    // Protokoll angepasst: Es empfängt jetzt die vergangenen Sekunden
    func timerDidFire(_ timer: PomodoroTimer, timeElapsed: Int)
}

private extension PomodoroTimer {
    struct Observation {
        weak var observer: TimerObserver?
    }
}

extension PomodoroTimer {
    func addObserver(_ observer: TimerObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = Observation(observer: observer)
    }
    
    func removeObserver(_ observer: TimerObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }
}
