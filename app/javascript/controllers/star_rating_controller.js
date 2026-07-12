import { Controller } from "@hotwired/stimulus"

// Click-to-select star rating input: keeps a hidden <input> in sync with
// the clicked star and fills every star up to and including it.
export default class extends Controller {
  static targets = ["star", "input"]

  select(event) {
    const value = Number(event.currentTarget.dataset.value)
    this.inputTarget.value = value

    this.starTargets.forEach((star) => {
      const filled = Number(star.dataset.value) <= value
      star.classList.toggle("text-red-600", filled)
      star.classList.toggle("text-grey-300", !filled)
    })
  }
}
