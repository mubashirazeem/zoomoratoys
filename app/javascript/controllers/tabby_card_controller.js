import { Controller } from "@hotwired/stimulus"

// Tabby's Checkout snippet (TabbyCard) — rendered under the selected Tabby
// radio on the checkout page, in place of hand-written "4 payments of X"
// copy. Requires the tabby-card.js script tag in the layout head — see
// https://docs.tabby.ai/pay-in-4-custom-integration/on-site-messaging.
//
// Same pattern as tabby_promo_controller.js: priceValueChanged (not
// connect()) initializes the widget — Stimulus fires it once on connect
// with the server-rendered price, then again whenever
// payment_method_controller.js#recalculateTotal writes a new price value
// after a gift-wrap / express-delivery toggle. There is no update method,
// so re-instantiating is the documented way to reflect a new amount.
//
// currency is always AED and price is always the AED total: Tabby settles
// in AED regardless of the display currency shown elsewhere on the page.
export default class extends Controller {
  static values = {
    publicKey: String,
    merchantCode: String,
    currency: { type: String, default: "AED" },
    price: String
  }

  priceValueChanged() {
    if (!window.TabbyCard || !this.priceValue || !this.element.id) return

    new TabbyCard({
      selector: `#${this.element.id}`,
      currency: this.currencyValue,
      price: this.priceValue,
      lang: "en",
      shouldInheritBg: false,
      publicKey: this.publicKeyValue,
      merchantCode: this.merchantCodeValue
    })
  }
}
