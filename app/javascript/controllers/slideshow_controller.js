import { Controller } from "@hotwired/stimulus"

// Fading hero slideshow with autoplay, prev/next arrows, and dot navigation.
export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { interval: { type: Number, default: 5500 } }

  connect() {
    this.index = 0
    this.show(0)
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.timer = setInterval(() => this.advance(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
  }

  restart() {
    this.stop()
    this.start()
  }

  advance() {
    this.show((this.index + 1) % this.slideTargets.length)
  }

  next() {
    this.advance()
    this.restart()
  }

  prev() {
    this.show((this.index - 1 + this.slideTargets.length) % this.slideTargets.length)
    this.restart()
  }

  goto(event) {
    this.show(Number(event.currentTarget.dataset.index))
    this.restart()
  }

  show(i) {
    this.index = i
    this.slideTargets.forEach((slide, n) => {
      slide.classList.toggle("opacity-100", n === i)
      slide.classList.toggle("opacity-0", n !== i)
      slide.classList.toggle("pointer-events-none", n !== i)
    })
    this.dotTargets.forEach((dot, n) => {
      dot.classList.toggle("bg-white", n === i)
      dot.classList.toggle("bg-white/40", n !== i)
      dot.setAttribute("aria-current", n === i ? "true" : "false")
    })
  }
}
