import { Controller } from "@hotwired/stimulus"

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])'

// Shared slide-out drawer behavior: open/close, backdrop dismiss, Escape to
// close, and a focus trap while open (see ACCESSIBILITY_GUIDELINES.md).
// Extended by nav_drawer_controller.js (mobile menu) and
// cart_drawer_controller.js (mini-cart) as separate Stimulus identifiers —
// same behavior, independent open/close state so one drawer opening never
// affects the other.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  open() {
    this.triggerElement = document.activeElement
    this.panelTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.handleKeydown)
    this.panelTarget.focus()
  }

  close() {
    this.panelTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.handleKeydown)
    this.triggerElement?.focus()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }

    if (event.key !== "Tab") return

    const focusable = Array.from(this.panelTarget.querySelectorAll(FOCUSABLE_SELECTOR))
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }
}
