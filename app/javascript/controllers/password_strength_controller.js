import { Controller } from "@hotwired/stimulus"

// Real-time password strength meter for the Ignition auth pages — not
// decorative. Scores 0-4 on length and character variety, fills a ring
// gauge proportionally and updates its label as the user types. Signals
// strength through fill amount and label text only, never color hue,
// since the site is black/red/white only.
const CIRCUMFERENCE = 94.2
const LEVELS = [
  { label: "Enter a password", fill: 0 },
  { label: "Too short", fill: 0.25 },
  { label: "Weak", fill: 0.5 },
  { label: "Good", fill: 0.75 },
  { label: "Strong", fill: 1 }
]

export default class extends Controller {
  static targets = ["input", "ring", "label"]

  check() {
    const level = LEVELS[this.score(this.inputTarget.value)]

    this.ringTarget.style.strokeDashoffset = CIRCUMFERENCE * (1 - level.fill)
    this.labelTarget.textContent = level.label
  }

  score(value) {
    if (value.length === 0) return 0
    if (value.length < 8) return 1

    let points = 0
    if (/[0-9]/.test(value)) points++
    if (/[A-Z]/.test(value)) points++
    if (/[^A-Za-z0-9]/.test(value)) points++

    if (points >= 2) return 4
    if (points === 1) return 3
    return 2
  }
}
