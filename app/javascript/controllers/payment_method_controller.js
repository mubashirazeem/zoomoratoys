import { Controller } from "@hotwired/stimulus"

// Toggles which payment/delivery state is active, and recomputes the Total
// shown — gift wrap and express delivery previously left the on-screen
// Total unchanged when toggled (a real bug Tabby's own QA caught: the
// number shown never matched the amount actually sent to Tabby/charged to
// the customer). All the inputs here — base totals, add-on prices, the
// display currency and its exchange rate — are still real server-computed
// values passed in as data, never invented client-side; this only ever
// sums/converts/formats them, the same way format_price does in Ruby.
//
// It also re-scores Tabby eligibility when the customer edits their phone
// in the Shipping form: Tabby's QA requires the option to come back (or go
// away) without a page reload once buyer info changes — see
// #refreshTabbyEligibility. The score itself is still Tabby's, fetched
// from CheckoutsController#tabby_eligibility (same call #show makes on the
// first paint), never guessed here.
export default class extends Controller {
  static targets = [
    "radio", "codTotal", "cardTotal",
    "deliveryRadio", "standardBadge", "expressBadge",
    "giftWrapCheckbox", "giftWrapNameWrap", "tabbyCard",
    "tabbyOption", "tabbyRadio", "tabbyDesc", "tabbyBadge",
    "totalAmount", "vatNote", "aedEquivalent", "tamaraCurrencyNote"
  ]

  static values = {
    codBaseCents: Number,
    cardBaseCents: Number,
    giftWrapCents: Number,
    expressCents: Number,
    displayCurrency: String,
    usdPerAed: Number,
    tabbyEligibilityUrl: String
  }

  connect() {
    this.recalculateTotal()

    // The phone field lives in the Shipping card, a sibling subtree of the
    // payment radios — but still inside this same <form>, which is this
    // controller's element. Editing it (or picking a saved address, which
    // dispatches a synthetic "input" — see address_picker_controller.js)
    // re-scores Tabby.
    this.phoneField = this.element.querySelector('[name="shipping_phone"]')
    if (this.phoneField && this.hasTabbyEligibilityUrlValue) {
      this._onPhoneInput = () => {
        clearTimeout(this._phoneDebounce)
        this._phoneDebounce = setTimeout(() => this.refreshTabbyEligibility(), 500)
      }
      this.phoneField.addEventListener("input", this._onPhoneInput)
    }
  }

  disconnect() {
    clearTimeout(this._phoneDebounce)
    if (this.phoneField && this._onPhoneInput) {
      this.phoneField.removeEventListener("input", this._onPhoneInput)
    }
  }

  toggle() {
    const selected = this.radioTargets.find((radio) => radio.checked)?.value
    const isCard = selected === "card"
    this.codTotalTargets.forEach((el) => el.classList.toggle("hidden", isCard))
    this.cardTotalTargets.forEach((el) => el.classList.toggle("hidden", !isCard))
    // Tabby's own checklist recommends showing the real Checkout snippet
    // (TabbyCard) under the selected Tabby radio, rather than hand-matching
    // their dynamic "4 payments of X/mo" copy in static text — see
    // tabby_card_controller.js.
    this.tabbyCardTargets.forEach((el) => el.classList.toggle("hidden", selected !== "tabby"))
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
    // Keep the TabbyCard snippet's amount in step with the Total — Tabby is
    // billed off the card base (coupon applies) plus the same add-ons, in
    // AED. Writing the value attribute re-inits the widget (see
    // tabby_card_controller.js#priceValueChanged).
    this.tabbyCardTargets.forEach((el) => {
      el.setAttribute("data-tabby-card-price-value", ((this.cardBaseCentsValue + addOnCents) / 100).toFixed(2))
    })
  }

  // Re-runs Tabby's pre-scoring for the phone now in the form and flips the
  // Tabby option between its live and greyed-out states in place. Anything
  // other than an explicit reject (network error, too-short number, Tabby
  // slow/unreachable) leaves the current state untouched — same
  // graceful-degradation stance as the server-side CheckEligibility.
  async refreshTabbyEligibility() {
    if (!this.hasTabbyRadioTarget || !this.hasTabbyEligibilityUrlValue) return

    const phone = (this.phoneField?.value || "").trim()
    if ((phone.match(/\d/g) || []).length < 8) return // not a plausible number yet

    let data
    try {
      const res = await fetch(`${this.tabbyEligibilityUrlValue}?phone=${encodeURIComponent(phone)}`, {
        headers: { Accept: "application/json" }
      })
      if (!res.ok) return
      data = await res.json()
    } catch {
      return
    }
    if (!data || typeof data.eligible !== "boolean") return

    this.applyTabbyEligibility(data.eligible, data.message)
  }

  applyTabbyEligibility(eligible, message) {
    const radio = this.tabbyRadioTarget
    if (radio.disabled === !eligible) return // already in the right state

    if (eligible) {
      radio.disabled = false
      radio.classList.remove("accent-grey-400")
      radio.classList.add("accent-red-600")
      this.tabbyOptionTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.tabbyOptionTarget.classList.add("cursor-pointer")
      this.tabbyBadgeTargets.forEach((el) => el.classList.remove("grayscale", "opacity-70"))
      this.tabbyDescTarget.textContent = "Split into 4 interest-free payments."
    } else {
      if (radio.checked) {
        radio.checked = false
        const fallback = this.radioTargets.find((r) => r.value === "pay_on_delivery")
        if (fallback) fallback.checked = true
      }
      radio.disabled = true
      radio.classList.remove("accent-red-600")
      radio.classList.add("accent-grey-400")
      this.tabbyOptionTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.tabbyOptionTarget.classList.remove("cursor-pointer")
      this.tabbyBadgeTargets.forEach((el) => el.classList.add("grayscale", "opacity-70"))
      this.tabbyDescTarget.textContent =
        message || "Sorry, Tabby is unable to approve this purchase. Please use an alternative payment method for your order."
    }

    this.toggle()
    this.recalculateTotal()
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
