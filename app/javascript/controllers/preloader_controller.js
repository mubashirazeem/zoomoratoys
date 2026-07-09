import { Controller } from "@hotwired/stimulus"

// Brand preloader: shown on every page view — full reloads AND in-page Turbo
// navigations (menu/link clicks) — then hidden once loading settles. Turbo
// replaces the <body> and re-connects this controller on each visit, so the
// intro animation replays every time. Reduced-motion users never see it.
export default class extends Controller {
  static values = { minDuration: { type: Number, default: 1300 } }

  connect() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    if (reduceMotion) {
      this.element.remove()
      return
    }

    document.documentElement.classList.add("overflow-hidden")
    this.start = performance.now()

    if (document.readyState === "complete") {
      this.scheduleHide()
    } else {
      this.onLoad = () => this.scheduleHide()
      window.addEventListener("load", this.onLoad, { once: true })
    }
  }

  disconnect() {
    document.documentElement.classList.remove("overflow-hidden")
    if (this.onLoad) window.removeEventListener("load", this.onLoad)
    clearTimeout(this.timer)
  }

  scheduleHide() {
    const elapsed = performance.now() - this.start
    const wait = Math.max(0, this.minDurationValue - elapsed)
    this.timer = setTimeout(() => this.hide(), wait)
  }

  hide() {
    this.element.classList.add("is-hidden")
    document.documentElement.classList.remove("overflow-hidden")
    setTimeout(() => this.element.remove(), 600)
  }
}
