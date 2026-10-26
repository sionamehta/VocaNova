# Voca Nova for iPhone

An iPhone app that runs the full Voca Nova app (coach, sight-reading, piano, Voca, lessons).
It opens the live site (https://sionamehta.github.io/VocaNova/) inside the app, so every
change merged to `main` shows up in the app too, with no rebuild.

What the app adds on top of the website:

- Microphone, camera and photo access with plain-English permission prompts.
- "Hey Voca" listening through iOS's own speech recognizer (`SpeechBridge.swift`).
- Sound that plays through the speaker even with the silent switch on.
- Pull down to refresh, outside links open in Safari, and an offline "Try again" screen.
- A teal app icon.

## Run it on the iPhone Simulator

1. On GitHub, click the green **Code** button, then **Download ZIP**, and unzip it.
2. Open the `iphone` folder and double-click `VocaNova.xcodeproj` (Xcode opens it).
3. At the top of Xcode, pick an iPhone simulator (for example "iPhone 16").
4. Press the Play button (or Cmd+R).
5. When the app asks to use the microphone or speech recognition, tap **Allow**.
   If your Mac asks whether Simulator can use the microphone, click **OK**.

The app needs Xcode 15 or newer and an internet connection.
To run on a real iPhone, choose your Apple ID under Signing & Capabilities > Team first.
