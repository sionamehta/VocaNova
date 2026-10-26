# ♫ Voca Nova

**Voca Nova** is a practice app for singers: choir students, ensemble and solo singers, and anyone learning to sight-read. It puts the tools a singer usually has to find in a dozen places (a piano, a metronome, solfège help, sight-reading exercises, and feedback on your singing) into one colorful app with an AI coach named **Voca**.

## Features

### 🎤 Coach (AI chat)
- Upload a **PDF or photo of your sheet music**, and the AI reads it into notes.
- Pick your voice part (Soprano, Alto, Tenor, Bass) and **see solfège written under every note**, including chromatic syllables like *fi*, *si* and *te*.
- Ask questions like *"What should altos watch out for?"* or *"Explain the dynamics in this piece."*
- **Play your part on piano**, alone or with all parts, at any speed, over any range of measures.
- **Make an audio file** of your part to listen to later.
- **Upload a recording or video of yourself singing** and get a score out of 100 for pitch, right notes, rhythm, staying in key and dynamics, with feedback for each measure.

### 🎼 Sight-Reading
- **6 levels**, from steps in C major to big leaps, hard keys and lots of accidentals.
- Choose your voice part, key, length and tempo.
- Before every exercise: **do–mi–sol–mi–do**, your starting note, then a **3 · 2 · 1 · Breathe** count-in.
- An **animated metronome** with 7 sounds, plus beat dots and a voice level meter.
- **Follow along** with a moving line, notes that light up, both, or neither.
- **Practice mode** gives you feedback. **Test mode** gives a letter grade and saves your score.
- From Level 3 up, the key is hidden, so you have to **find do yourself**.
- **Lessons and tips**: reading the staff, rhythm, reading key signatures (with a quiz), solfège, intervals, accidentals, the 30-second scan, and a practice plan.

### 🎹 Piano
- A full keyboard that works on phones, with note-name or solfège labels.
- Find any note by syllable and key, play chords and scales, and hear the starting note of your piece.

### 🗣️ Hey Voca
- A voice assistant: *"Hey Voca, play C sharp."* *"Play a G minor chord."* *"Play sol in E flat."* *"Play my starting note."*
- Remembers your conversation, so you can ask follow-ups like *"explain that more."*
- You can type commands too.

## How to use it

It's all one file: **`index.html`**.

- **Online:** open the GitHub Pages link for this repository (Settings → Pages).
- **On your computer:** download `index.html` and open it in Chrome or Edge. It needs an internet connection to load the sheet-music and PDF libraries.

## What works where

| Feature | Inside Claude | GitHub Pages / your computer |
|---|---|---|
| Piano, metronome, sight-reading, lessons | ✅ | ✅ |
| Solfège and playback of the example piece | ✅ | ✅ |
| Grading uploaded recordings | ✅ | ✅ |
| Microphone (Hey Voca listening, live recording) | ❌ blocked | ✅ |
| AI coach chat, reading PDFs, Voca's smart answers | ✅ | ❌ needs an AI connection |

The AI features use Claude through the Claude app. To get them working on your own site, set up the small coach server in [`server/`](server/README.md), which connects to the Claude API with your own API key.

The **Test audio** button at the top checks your speakers, your microphone and a short recording, and tells you which note you're singing.

## Built with

- Plain HTML, CSS and JavaScript in a single file
- [VexFlow](https://www.vexflow.com/) for drawing sheet music
- [PDF.js](https://mozilla.github.io/pdf.js/) for reading PDF sheet music
- The Web Audio API for the piano, metronome and pitch detection
- The Web Speech API for "Hey Voca"
- Claude for the AI coach

## Roadmap

- [ ] Show lyrics from the sheet music under the notes
- [ ] A singing voice that sings the lyrics
- [ ] Accounts for students and choir teachers, with assignments and progress tracking
- [ ] Vocal warm-ups, ear training and rhythm games
- [ ] A phone app

## Note on sheet music

Upload music only for your own practice. Please don't use Voca Nova to share or distribute copyrighted scores.
