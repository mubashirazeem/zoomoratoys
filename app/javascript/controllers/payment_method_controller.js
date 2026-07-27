import { Controller } from "@hotwired/stimulus"

// Toggles which pre-rendered total is shown when the payment method radio
// changes — both totals are computed server-side (see checkouts/show.html.erb),
// this only ever swaps visibility, never recomputes money in JS.
export default class extends Controller {
  static targets = ["radio", "codTotal", "cardTotal"]

  toggle() {
    const isCard = this.radioTargets.find((radio) => radio.checked)?.value === "card"
    this.codTotalTargets.forEach((el) => el.classList.toggle("hidden", isCard))
    this.cardTotalTargets.forEach((el) => el.classList.toggle("hidden", !isCard))
  }
}
