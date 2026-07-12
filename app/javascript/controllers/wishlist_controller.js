import { Controller } from "@hotwired/stimulus"

// Client-side wishlist item removal — presentational only, no persistence
// yet (see WishlistsController's doc comment, same pattern as the cart).
export default class extends Controller {
  static targets = ["item", "empty"]

  removeItem(event) {
    event.currentTarget.closest("[data-wishlist-target='item']")?.remove()
    if (this.itemTargets.length === 0 && this.hasEmptyTarget) {
      this.emptyTarget.hidden = false
    }
  }
}
