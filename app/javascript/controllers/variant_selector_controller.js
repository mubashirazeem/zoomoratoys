import { Controller } from "@hotwired/stimulus"

// Generic selector for one group of variant options (color swatches, size
// or material pills) — one controller instance per group, so Color/Size/
// Material each track their own selection independently. No variants
// backend yet (see Catalog::ProductVariantsComponent) — selecting an
// option updates this group's own label and pressed state only.
export default class extends Controller {
  static targets = ["option", "label"]

  select(event) {
    const chosen = event.currentTarget

    this.optionTargets.forEach((option) => {
      const selected = option === chosen
      option.setAttribute("aria-pressed", String(selected))
      option.classList.toggle("border-red-600", selected)
      option.classList.toggle("border-grey-200", !selected)
      option.classList.toggle("text-red-600", selected)
      option.classList.toggle("text-ink-950", !selected)
    })

    if (this.hasLabelTarget) this.labelTarget.textContent = chosen.dataset.variantName
  }
}
