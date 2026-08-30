import { Controller } from "@hotwired/stimulus"

// Tabby's on-site "as low as X/month" messaging (Product and Cart snippets
// — the same TabbyPromo component for both; only the `source` value
// differs). Requires the tabby-promo.js script tag in the layout head —
// see https://docs.tabby.ai/pay-in-4-custom-integration/on-site-messaging.
//
// priceValueChanged (not connect()) is what actually initializes the
// widget — Stimulus fires it once on connect with the initial price, then
// again any time something writes a new data-tabby-promo-price-value
// attribute. Tabby's own docs say to re-init (there's no update method)
// whenever the price changes, e.g. a variant selector — see
// product_variant_picker_controller.js#sync, which writes this
// controller's price value whenever the selected variant changes.
export default class extends Controller {
  static values = {
    publicKey: String,
    merchantCode: String,
    currency: { type: String, default: "AED" },
    source: String,
    price: String
  }

  priceValueChanged() {
    if (!window.TabbyPromo || !this.priceValue || !this.element.id) return

    new TabbyPromo({
      selector: `#${this.element.id}`,
      currency: this.currencyValue,
      price: this.priceValue,
      publicKey: this.publicKeyValue,
      merchantCode: this.merchantCodeValue,
      lang: "en",
      source: this.sourceValue
    })
  }
}
