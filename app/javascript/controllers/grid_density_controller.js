import { Controller } from "@hotwired/stimulus"

// "View as" density switcher for the collection grid. Swaps the large-screen
// column count on the grid and marks the active option.
export default class extends Controller {
  static targets = ["grid", "option"]

  set(event) {
    const cols = event.currentTarget.dataset.cols
    this.gridTarget.className = this.gridTarget.className.replace(
      /lg:grid-cols-\d+/,
      `lg:grid-cols-${cols}`
    )
    this.optionTargets.forEach((option) => {
      const active = option === event.currentTarget
      option.classList.toggle("bg-red-600", active)
      option.classList.toggle("text-white", active)
      option.classList.toggle("text-grey-400", !active)
    })
  }
}
