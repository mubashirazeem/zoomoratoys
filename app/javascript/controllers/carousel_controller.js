import { Controller } from "@hotwired/stimulus"

// Horizontal scroll-snap carousel (product rails). Native scroll behavior
// plus a couple of arrow buttons — no external carousel library needed.
export default class extends Controller {
  static targets = ["track"]

  next() {
    this.scrollByAmount(1)
  }

  prev() {
    this.scrollByAmount(-1)
  }

  scrollByAmount(direction) {
    const track = this.trackTarget
    const amount = track.clientWidth * 0.8 * direction
    track.scrollBy({ left: amount, behavior: "smooth" })
  }
}
