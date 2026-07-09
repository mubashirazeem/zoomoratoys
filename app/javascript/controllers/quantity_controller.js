import { Controller } from "@hotwired/stimulus"

// Client-side quantity stepper for the product buy box (presentational — no
// cart backend this pass). Clamps to a minimum of 1.
export default class extends Controller {
  static targets = ["input"]

  decrease() {
    this.setValue(this.value - 1)
  }

  increase() {
    this.setValue(this.value + 1)
  }

  get value() {
    return parseInt(this.inputTarget.value, 10) || 1
  }

  setValue(next) {
    this.inputTarget.value = Math.max(1, next)
  }
}
