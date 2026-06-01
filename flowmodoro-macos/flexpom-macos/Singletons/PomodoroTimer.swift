import Cocoa

class PomodoroTimer {
    static let shared = PomodoroTimer()
    
    private var timer: Timer?
    private var observations = [ObjectIdentifier: Observation]()
    
    // Speichert die exakte Uhrzeit des letzten Ticks
    private var lastTickDate: Date?
    
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
        // Zerstört den Timer VOR dem Ruhezustand.
        // Das verhindert, dass macOS beim Aufwachen angesammelte, alte Ticks nachholt.
        self.timer?.invalidate()
        self.timer = nil
    }

    @objc private func handleWake(_ notification: Notification) {
        // Startet einen komplett frischen Timer.
        // 'lastTickDate' wird dabei exakt auf die aktuelle Aufwach-Zeit gesetzt.
        // Der nächste Tick erfolgt dann ganz sauber genau 1 Sekunde später.
        self.start()
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
                    // Cleanup, falls der Observer nicht mehr im RAM ist
                    guard let observer = observation.observer else {
                        self.observations.removeValue(forKey: id)
                        continue
                    }
                    
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
