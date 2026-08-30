import { Controller } from "@hotwired/stimulus"

// Toggles which pre-rendered total/badge is shown as the payment method,
// delivery method, and gift-wrap checkbox change — every figure shown is
// computed server-side (see checkouts/show.html.erb), this only ever swaps
// visibility, never recomputes money in JS.
export default class extends Controller {
  static targets = [
    "radio", "codTotal", "cardTotal",
    "deliveryRadio", "standardBadge", "expressBadge",
    "giftWrapCheckbox", "giftWrapNameWrap", "tabbyCheckoutPromo"
  ]

  toggle() {
    const selected = this.radioTargets.find((radio) => radio.checked)?.value
    const isCard = selected === "card"
    this.codTotalTargets.forEach((el) => el.classList.toggle("hidden", isCard))
    this.cardTotalTargets.forEach((el) => el.classList.toggle("hidden", !isCard))
    // Tabby's own checklist recommends showing the real Checkout snippet
    // under the selected Tabby radio, rather than hand-matching their
    // dynamic "4 payments of X/mo" copy in static text — see
    // tabby_promo_controller.js.
    this.tabbyCheckoutPromoTargets.forEach((el) => el.classList.toggle("hidden", selected !== "tabby"))
  }

  toggleDelivery() {
    const isExpress = this.deliveryRadioTargets.find((radio) => radio.checked)?.value === "express"
    this.standardBadgeTargets.forEach((el) => el.classList.toggle("hidden", isExpress))
    this.expressBadgeTargets.forEach((el) => el.classList.toggle("hidden", !isExpress))
  }

  toggleGiftWrapName() {
    const checked = this.giftWrapCheckboxTarget.checked
    this.giftWrapNameWrapTargets.forEach((el) => el.classList.toggle("hidden", !checked))
  }
}
