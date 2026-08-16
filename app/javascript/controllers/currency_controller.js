import { Controller } from "@hotwired/stimulus"

// Only ever opens/closes the dropdown panel in the header's utility bar —
// picking a currency is a real form submit (see CurrenciesController),
// which redirects back with the cookie set and the whole page re-rendered
// server-side in the new currency. Nothing here recomputes a price.
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  toggle() {
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
