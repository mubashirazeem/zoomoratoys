import { Controller } from "@hotwired/stimulus"

// Reveals the compact logo/search/cart controls inside the sticky nav bar
// once the tall main header row has scrolled out of view, so the sticky bar
// stays useful without permanently duplicating the main header.
export default class extends Controller {
  static targets = ["compact"]
  static values = { threshold: { type: Number, default: 200 } }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const condensed = window.scrollY > this.thresholdValue
    this.compactTargets.forEach((el) => el.classList.toggle("hidden", !condensed))
  }
}
