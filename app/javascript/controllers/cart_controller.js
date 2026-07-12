import { Controller } from "@hotwired/stimulus"

// Client-side cart totals: recalculates each line's total and the
// subtotal/total as quantities change, a line is removed, or gift wrap is
// toggled — presentational only, no persistence yet (see CartsController's
// doc comment). Each cart surface (the full /cart page, the mini-cart
// drawer) gets its own independent instance; they don't sync with each
// other in this pass since neither is backed by real state to sync from.
export default class extends Controller {
  static targets = ["line", "lineTotal", "subtotal", "total", "giftWrapToggle", "giftWrapRow"]
  static values = { giftWrapCents: { type: Number, default: 0 } }

  connect() {
    this.recalculate()
  }

  removeLine(event) {
    event.currentTarget.closest("[data-cart-target='line']")?.remove()
    this.recalculate()
  }

  recalculate() {
    let subtotalCents = 0

    this.lineTargets.forEach((line) => {
      const priceCents = Number(line.dataset.priceCents)
      const quantityInput = line.querySelector("[data-quantity-target='input']")
      const quantity = Math.max(1, parseInt(quantityInput?.value, 10) || 1)
      const lineTotalCents = priceCents * quantity

      const lineTotalTarget = line.querySelector("[data-cart-target='lineTotal']")
      if (lineTotalTarget) lineTotalTarget.textContent = this.formatAed(lineTotalCents)

      subtotalCents += lineTotalCents
    })

    const giftWrapping = this.hasGiftWrapToggleTarget && this.giftWrapToggleTarget.checked
    if (this.hasGiftWrapRowTarget) this.giftWrapRowTarget.hidden = !giftWrapping

    const totalCents = subtotalCents + (giftWrapping ? this.giftWrapCentsValue : 0)

    this.subtotalTargets.forEach((el) => (el.textContent = this.formatAed(subtotalCents)))
    this.totalTargets.forEach((el) => (el.textContent = this.formatAed(totalCents)))
  }

  formatAed(cents) {
    const whole = Math.round(cents / 100)
    return `AED ${whole.toLocaleString("en-US")}`
  }
}
