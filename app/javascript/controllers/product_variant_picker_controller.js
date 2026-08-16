import { Controller } from "@hotwired/stimulus"

// Real variant picker: variantsValue is the product's actual ProductVariant
// rows (id, options, price_cents, sku, stock_quantity), serialized server-
// side by Catalog::ProductVariantsComponent#variants_json. Selecting an
// option looks up the exact matching variant and updates price/SKU/stock
// and the hidden product_variant_id field the surrounding Add to
// Cart/Buy It Now form submits — not just cosmetic state.
export default class extends Controller {
  static values = { variants: Array, currency: { type: String, default: "AED" }, usdPerAed: Number }
  static targets = [
    "option", "label", "priceSummary", "sku", "stockNotice",
    "unavailable", "variantIdField", "addToCartButton"
  ]

  connect() {
    this.selected = {}
    this.optionTargets.forEach((option) => {
      if (option.getAttribute("aria-pressed") === "true") {
        this.selected[option.dataset.optionType] = option.dataset.optionValue
      }
    })
    this.sync()
  }

  select(event) {
    const chosen = event.currentTarget
    const { optionType, optionValue } = chosen.dataset
    this.selected[optionType] = optionValue

    this.optionTargets.forEach((option) => {
      if (option.dataset.optionType !== optionType) return

      const isSelected = option === chosen
      option.setAttribute("aria-pressed", String(isSelected))
      option.classList.toggle("border-red-600", isSelected)
      option.classList.toggle("text-red-600", isSelected)
      option.classList.toggle("border-grey-200", !isSelected)
      option.classList.toggle("text-ink-950", !isSelected)
    })

    this.labelTargets.forEach((label) => {
      if (label.dataset.optionType === optionType) label.textContent = optionValue
    })

    this.sync()
  }

  sync() {
    // No variants at all — a plain product with nothing to pick. Leave the
    // Add to Cart/Buy It Now buttons alone entirely (they're valid without
    // a variant_id); there's nothing to validate or disable here.
    if (this.variantsValue.length === 0) return

    const match = this.variantsValue.find((variant) => this.matches(variant.options))

    if (match) {
      if (this.hasVariantIdFieldTarget) this.variantIdFieldTarget.value = match.id
      if (this.hasSkuTarget) this.skuTarget.textContent = match.sku
      if (this.hasPriceSummaryTarget) this.priceSummaryTarget.textContent = this.formatPrice(match.price_cents)
      if (this.hasStockNoticeTarget) this.stockNoticeTarget.textContent = match.stock_quantity > 0 ? "" : "Out of stock"
      if (this.hasUnavailableTarget) this.unavailableTarget.hidden = true
      this.addToCartButtonTargets.forEach((button) => (button.disabled = match.stock_quantity <= 0))
    } else {
      if (this.hasVariantIdFieldTarget) this.variantIdFieldTarget.value = ""
      if (this.hasUnavailableTarget) this.unavailableTarget.hidden = false
      this.addToCartButtonTargets.forEach((button) => (button.disabled = true))
    }
  }

  matches(options) {
    const keys = Object.keys(options)
    return keys.length === Object.keys(this.selected).length &&
      keys.every((key) => this.selected[key] === options[key])
  }

  // Mirrors ApplicationHelper#format_price exactly (same conversion, same
  // rounding) so a variant swap never shows a different price than a full
  // page load would have server-rendered for the same variant. This never
  // affects what's actually charged — Order.create_from_cart! re-derives
  // the real AED price server-side from variant_id at checkout, so even a
  // wrong client-side estimate here couldn't cause an incorrect charge.
  formatPrice(cents) {
    if (this.currencyValue !== "USD") return `AED ${Math.round(cents / 100).toLocaleString("en-US")}`

    const usdCents = Math.round(cents * this.usdPerAedValue)
    const whole = Math.floor(usdCents / 100)
    const subUnits = String(usdCents % 100).padStart(2, "0")
    return `$${whole.toLocaleString("en-US")}.${subUnits} USD`
  }
}
