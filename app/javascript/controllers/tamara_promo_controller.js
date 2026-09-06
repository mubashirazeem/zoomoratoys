import { Controller } from "@hotwired/stimulus"

// Tamara's on-site "Tamara Summary" widget — see the tamaraWidgetConfig
// script tag in layouts/_head.html.erb for the global setup this depends
// on. Confirmed live against https://widget-docs.tamara.co (their real
// interactive widget-builder tool — docs.tamara.co itself has no readable
// spec for this).
//
// Unlike Tabby's TabbyPromo (a JS class instantiated per element),
// Tamara's <tamara-widget> is a native custom element with no per-instance
// constructor — it reads its own `amount` attribute and window.
// tamaraWidgetConfig, then window.TamaraWidgetV2.refresh() re-renders
// every <tamara-widget> on the page. Their own docs only show refresh()
// for a language/country change, but a variant-driven price change is the
// same "value changed after initial render" case, so the same call
// applies here — same reasoning as Tabby's priceValueChanged.
export default class extends Controller {
  static values = { price: String }

  priceValueChanged() {
    if (!window.TamaraWidgetV2 || !this.priceValue) return

    this.element.setAttribute("amount", this.priceValue)
    window.TamaraWidgetV2.refresh()
  }
}
