import { Controller } from "@hotwired/stimulus"

// Reveals a fixed bottom add-to-cart bar once the main buy box (the anchor)
// has scrolled above the viewport, and hides it again near the page bottom.
export default class extends Controller {
  static targets = ["bar", "anchor"]

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const anchorBelowFold = this.anchorTarget.getBoundingClientRect().bottom > 0
    const nearBottom = window.innerHeight + window.scrollY >= document.body.offsetHeight - 120
    const show = !anchorBelowFold && !nearBottom
    this.barTarget.classList.toggle("translate-y-full", !show)
  }
}
