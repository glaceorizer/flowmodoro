import Cocoa

class PomodoroTimer {
    static let shared = PomodoroTimer()
    
    private var timer: Timer?
    private var observations = [ObjectIdentifier: Observation]()
    
    // Speichert die exakte Uhrzeit des letzten Ticks
    private var lastTickDate: Date?
    
    // NEU: Speichert den Zeitpunkt des Ruhezustands
    private var sleepDate: Date?
    
    private init() {
        setupSleepWakeObservers()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    // MARK: - Sleep/Wake Handling
    
    private func setupSleepWakeObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleSleep(_ notification: Notification) {
        // Zeitpunkt speichern, an dem der Mac zugeklappt wird
        sleepDate = Date()
    }

    @objc private func handleWake(_ notification: Notification) {
        guard let sleep = sleepDate else { return }
        
        let timeAsleep = Date().timeIntervalSince(sleep)
        
        // Den letzten Tick um die geschlafene Zeit nach vorne schieben.
        // Dadurch tut der Timer so, als wäre in der Zwischenzeit keine Zeit vergangen.
        if let last = lastTickDate {
            lastTickDate = last.addingTimeInterval(timeAsleep)
        }
        
        sleepDate = nil
    }
    
    // MARK: - Timer Logic
    
    func start() {
        self.timer?.invalidate()
        self.lastTickDate = Date()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let lastTick = self.lastTickDate else { return }
            
            let now = Date()
            // Berechne die reale vergangene Zeit
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
        self.sleepDate = nil
    }
}

// MARK: - Observable

protocol TimerObserver: AnyObject {
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
