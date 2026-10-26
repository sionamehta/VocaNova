import Foundation
import AVFoundation
import Speech
import WebKit

/// Gives the web page a `SpeechRecognition` that runs on iOS's own speech
/// recognizer, so "Hey Voca" can listen inside the app.
///
/// The page talks to it through `window.webkit.messageHandlers.vnSpeech`
/// (start / stop / abort), and it answers by calling `window.__vnSpeech(...)`
/// with start, result, error and end events.
final class SpeechBridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "vnSpeech"

    weak var webView: WKWebView?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var sessionId = 0
    private var running = false
    private var continuous = false
    private var interim = false
    private var lastText = ""
    private var silenceTimer: Timer?
    private var quickFailures = 0
    private var taskStarted = Date()

    /// How long a pause has to be before what was said counts as finished.
    private let pause: TimeInterval = 1.1

    // MARK: Messages from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { return }
        let id = (body["id"] as? NSNumber)?.intValue ?? 0
        switch cmd {
        case "start":
            start(id: id,
                  lang: body["lang"] as? String ?? "en-US",
                  continuous: (body["continuous"] as? NSNumber)?.boolValue ?? false,
                  interim: (body["interim"] as? NSNumber)?.boolValue ?? false)
        case "stop":
            if id == sessionId { finish(keepWords: true) }
        case "abort":
            if id == sessionId { finish(keepWords: false) }
        default:
            break
        }
    }

    /// Stops listening without telling the page (used when the page reloads).
    func stopAll() {
        teardown()
    }

    // MARK: Listening

    private func start(id: Int, lang: String, continuous: Bool, interim: Bool) {
        if running { finish(keepWords: false) }
        sessionId = id
        self.continuous = continuous
        self.interim = interim
        quickFailures = 0

        Self.askPermission { [weak self] allowed in
            guard let self = self, self.sessionId == id else { return }
            guard allowed else {
                self.emit(["type": "error", "error": "not-allowed"])
                self.emit(["type": "end"])
                return
            }
            do {
                try self.begin(lang: lang)
                self.emit(["type": "start"])
            } catch {
                self.teardown()
                self.emit(["type": "error", "error": "audio-capture"])
                self.emit(["type": "end"])
            }
        }
    }

    private static func askPermission(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return done(false) }
                let micDone: (Bool) -> Void = { granted in DispatchQueue.main.async { done(granted) } }
                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission(completionHandler: micDone)
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission(micDone)
                }
            }
        }
    }

    private enum BridgeError: Error { case unavailable, noInput }

    private func begin(lang: String) throws {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: lang)) ?? SFSpeechRecognizer(),
              rec.isAvailable else { throw BridgeError.unavailable }
        recognizer = rec

        AudioSessionSetup.activate()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw BridgeError.noInput }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        try engine.start()
        running = true
        newTask()
    }

    private func newTask() {
        guard running, let rec = recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
        lastText = ""
        taskStarted = Date()
        let id = sessionId

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.running, self.sessionId == id, self.request === req else { return }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal { return self.commit(text) }
                    if text != self.lastText {
                        self.lastText = text
                        self.quickFailures = 0
                        if self.interim { self.emit(["type": "result", "text": text, "final": false]) }
                        self.armSilenceTimer()
                    }
                } else if error != nil {
                    self.taskEnded()
                }
            }
        }
    }

    /// The recognizer gave up (usually "no speech heard"). Keep listening.
    private func taskEnded() {
        if !lastText.isEmpty { return commit(lastText) }
        guard continuous else { return finish(keepWords: false) }
        if Date().timeIntervalSince(taskStarted) < 1 {
            quickFailures += 1
            if quickFailures >= 5 {
                // Recognition keeps failing right away (no internet, or not supported here).
                emit(["type": "error", "error": "service-not-allowed"])
                return finish(keepWords: false)
            }
        } else {
            quickFailures = 0
        }
        let id = sessionId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.running, self.sessionId == id else { return }
            self.restartTask()
        }
    }

    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: pause, repeats: false) { [weak self] _ in
            guard let self = self, self.running else { return }
            self.commit(self.lastText)
        }
    }

    /// Sends what was said as a finished phrase, then listens for the next one.
    private func commit(_ text: String) {
        silenceTimer?.invalidate()
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { emit(["type": "result", "text": words, "final": true]) }
        if continuous { restartTask() } else { finish(keepWords: false) }
    }

    private func restartTask() {
        let oldTask = task
        request?.endAudio()
        request = nil
        task = nil
        oldTask?.cancel()
        newTask()
    }

    private func finish(keepWords: Bool) {
        guard running else { return }
        let words = lastText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keepWords && !words.isEmpty { emit(["type": "result", "text": words, "final": true]) }
        teardown()
        emit(["type": "end"])
    }

    private func teardown() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        running = false
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        lastText = ""
    }

    // MARK: Events to the page

    private func emit(_ payload: [String: Any]) {
        var event = payload
        event["id"] = sessionId
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.__vnSpeech && window.__vnSpeech(\(json))", completionHandler: nil)
    }

    // MARK: Script for the page

    static let script = """
    (function () {
      var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.vnSpeech;
      if (!bridge) return;
      var active = null, seq = 0;
      function makeResult(text, isFinal) {
        var r = [{ transcript: text, confidence: isFinal ? 0.9 : 0.5 }];
        r.isFinal = isFinal;
        r.item = function (i) { return this[i]; };
        return r;
      }
      function list(items) {
        items.item = function (i) { return this[i]; };
        return items;
      }
      function Recognition() {
        this.continuous = false;
        this.interimResults = false;
        this.lang = 'en-US';
        this.maxAlternatives = 1;
        this.onstart = this.onresult = this.onerror = this.onend = null;
        this._id = 0;
        this._finals = [];
        this._listeners = {};
      }
      Recognition.prototype.addEventListener = function (type, fn) {
        (this._listeners[type] = this._listeners[type] || []).push(fn);
      };
      Recognition.prototype.removeEventListener = function (type, fn) {
        var l = this._listeners[type] || [];
        var i = l.indexOf(fn);
        if (i >= 0) l.splice(i, 1);
      };
      Recognition.prototype._fire = function (type, ev) {
        ev.type = type;
        ev.target = this;
        var h = this['on' + type];
        if (typeof h === 'function') { try { h.call(this, ev); } catch (e) { console.error(e); } }
        (this._listeners[type] || []).slice().forEach(function (fn) {
          try { fn.call(this, ev); } catch (e) { console.error(e); }
        }, this);
      };
      Recognition.prototype.start = function () {
        if (active === this && this._id) throw new DOMException('Recognition has already started.', 'InvalidStateError');
        active = this;
        this._id = ++seq;
        this._finals = [];
        bridge.postMessage({ cmd: 'start', id: this._id, lang: this.lang || 'en-US',
                             continuous: !!this.continuous, interim: !!this.interimResults });
      };
      Recognition.prototype.stop = function () { if (this._id) bridge.postMessage({ cmd: 'stop', id: this._id }); };
      Recognition.prototype.abort = function () { if (this._id) bridge.postMessage({ cmd: 'abort', id: this._id }); };

      window.__vnSpeech = function (m) {
        var r = active;
        if (!r || m.id !== r._id) return;
        if (m.type === 'start') {
          r._fire('start', {});
        } else if (m.type === 'result') {
          var results, index;
          if (m.final) {
            r._finals.push(makeResult(m.text, true));
            results = r._finals.slice();
            index = results.length - 1;
          } else {
            results = r._finals.concat([makeResult(m.text, false)]);
            index = r._finals.length;
          }
          r._fire('result', { resultIndex: index, results: list(results) });
        } else if (m.type === 'error') {
          r._fire('error', { error: m.error, message: '' });
        } else if (m.type === 'end') {
          r._id = 0;
          if (active === r) active = null;
          r._fire('end', {});
        }
      };
      window.SpeechRecognition = Recognition;
      window.webkitSpeechRecognition = Recognition;
    })();
    """
}
