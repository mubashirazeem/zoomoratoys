import { Controller } from "@hotwired/stimulus"

// Type-to-filter for a long checkbox list (e.g. the Color filter, which can
// run past 100 options on a large category) — hides options whose label
// text doesn't match, entirely client-side since every option is already
// rendered. General-purpose: works for any list of data-checklist-search-target="option"
// elements, not color-specific.
export default class extends Controller {
  static targets = ["input", "option", "empty"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const matches = option.dataset.checklistSearchLabel.includes(query)
      option.classList.toggle("hidden", !matches)
      if (matches) visibleCount++
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
    }
  }
}
