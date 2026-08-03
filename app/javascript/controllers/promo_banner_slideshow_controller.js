import { Controller } from "@hotwired/stimulus"

// Auto-advancing slideshow for the homepage's promotional banners — slides
// sit side by side in a flex track, and moving to a slide shifts the track
// sideways by full slide-widths (client feedback, 2026-08-02: "this picture
// should be moving sideways"). The offset is computed in pixels from the
// rendered slide width rather than a CSS percentage, so it's correct at any
// viewport size without needing a resize listener.
//
// Deliberately much simpler than slideshow_controller.js (the hero's 3D cube
// carousel): that controller's depth/tilt/Ken-Burns treatment is a hero-only
// flourish, overkill for this lower-key section further down the page.
//
// Autoplay is skipped entirely under prefers-reduced-motion; the dots stay
// fully functional either way, so every banner is still reachable.
export default class extends Controller {
  static targets = ["track", "slide", "dot"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.index = 0
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.stop()
    if (this.slideTargets.length < 2) return
    this.timer = setInterval(() => this.advance(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
  }

  advance() {
    this.show((this.index + 1) % this.slideTargets.length)
  }

  next() {
    this.show((this.index + 1) % this.slideTargets.length)
    this.start()
  }

  prev() {
    const len = this.slideTargets.length
    this.show((this.index - 1 + len) % len)
    this.start()
  }

  goto(event) {
    this.show(Number(event.currentTarget.dataset.index))
    this.start()
  }

  show(i) {
    this.index = i

    if (this.hasTrackTarget) {
      const slideWidth = this.slideTargets[0].offsetWidth
      this.trackTarget.style.transform = `translateX(-${i * slideWidth}px)`
    }

    this.slideTargets.forEach((slide, n) => {
      const active = n === i
      slide.classList.toggle("is-active", active)
      slide.setAttribute("aria-hidden", active ? "false" : "true")
    })
    this.dotTargets.forEach((dot, n) => dot.setAttribute("aria-current", n === i ? "true" : "false"))
  }
}
