import { Controller } from "@hotwired/stimulus"

// Toggles which payment/delivery state is active, and recomputes the Total
// shown — gift wrap and express delivery previously left the on-screen
// Total unchanged when toggled (a real bug Tabby's own QA caught: the
// number shown never matched the amount actually sent to Tabby/charged to
// the customer). All the inputs here — base totals, add-on prices, the
// display currency and its exchange rate — are still real server-computed
// values passed in as data, never invented client-side; this only ever
// sums/converts/formats them, the same way format_price does in Ruby.
export default class extends Controller {
  static targets = [
    "radio", "codTotal", "cardTotal",
    "deliveryRadio", "standardBadge", "expressBadge",
    "giftWrapCheckbox", "giftWrapNameWrap", "tabbyCheckoutPromo",
    "totalAmount", "vatNote", "aedEquivalent", "tabbyCurrencyNote", "tamaraCurrencyNote"
  ]

  static values = {
    codBaseCents: Number,
    cardBaseCents: Number,
    giftWrapCents: Number,
    expressCents: Number,
    displayCurrency: String,
    usdPerAed: Number
  }

  connect() {
    this.recalculateTotal()
  }

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
    this.tabbyCurrencyNoteTargets.forEach((el) => el.classList.toggle("hidden", selected !== "tabby"))
    this.tamaraCurrencyNoteTargets.forEach((el) => el.classList.toggle("hidden", selected !== "tamara"))
  }

  toggleDelivery() {
    const isExpress = this.deliveryRadioTargets.find((radio) => radio.checked)?.value === "express"
    this.standardBadgeTargets.forEach((el) => el.classList.toggle("hidden", isExpress))
    this.expressBadgeTargets.forEach((el) => el.classList.toggle("hidden", !isExpress))
    this.recalculateTotal()
  }

  toggleGiftWrapName() {
    const checked = this.giftWrapCheckboxTarget.checked
    this.giftWrapNameWrapTargets.forEach((el) => el.classList.toggle("hidden", !checked))
    this.recalculateTotal()
  }

  recalculateTotal() {
    if (!this.hasTotalAmountTarget) return

    const isExpress = this.hasDeliveryRadioTarget && this.deliveryRadioTargets.find((radio) => radio.checked)?.value === "express"
    const giftWrapped = this.hasGiftWrapCheckboxTarget && this.giftWrapCheckboxTarget.checked
    const addOnCents = (isExpress ? this.expressCentsValue : 0) + (giftWrapped ? this.giftWrapCentsValue : 0)

    this.totalAmountTargets.forEach((el) => {
      const baseCents = el.dataset.paymentMethodBase === "card" ? this.cardBaseCentsValue : this.codBaseCentsValue
      el.textContent = this.formatMoney(baseCents + addOnCents)
    })
    this.vatNoteTargets.forEach((el) => {
      const baseCents = el.dataset.paymentMethodBase === "card" ? this.cardBaseCentsValue : this.codBaseCentsValue
      el.textContent = `Includes VAT (5%): ${this.formatAedPrecise(this.vatPortion(baseCents + addOnCents))}`
    })
    this.aedEquivalentTargets.forEach((el) => {
      const baseCents = el.dataset.paymentMethodBase === "card" ? this.cardBaseCentsValue : this.codBaseCentsValue
      el.textContent = `(${this.formatAed(baseCents + addOnCents)})`
    })
  }

  // Same VAT-inclusive breakdown as Order.vat_portion_of / ApplicationHelper
  // #vat_inclusive_note — 5% backed out of a total that already includes it.
  vatPortion(totalCents) {
    return Math.round(totalCents - totalCents / 1.05)
  }

  formatMoney(cents) {
    return this.displayCurrencyValue === "AED" ? this.formatAed(cents) : this.formatUsd(cents)
  }

  formatAed(cents) {
    return `AED ${this.withThousands(Math.round(cents / 100))}`
  }

  // Matches ApplicationHelper#format_aed_precise — keeps fils, needed for
  // the VAT breakdown (5% of a whole-dirham total routinely isn't one).
  formatAedPrecise(cents) {
    const whole = Math.floor(cents / 100)
    const fils = cents % 100
    return `AED ${this.withThousands(whole)}.${String(fils).padStart(2, "0")}`
  }

  formatUsd(cents) {
    const usdCents = Math.round(cents * this.usdPerAedValue)
    const whole = Math.floor(usdCents / 100)
    const sub = usdCents % 100
    return `$${this.withThousands(whole)}.${String(sub).padStart(2, "0")} USD`
  }

  withThousands(number) {
    return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }
}
