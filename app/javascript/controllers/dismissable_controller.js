import { Controller } from "@hotwired/stimulus"

// Removes its own element when a child with data-action="dismissable#close"
// is activated. Used by the announcement bar.
export default class extends Controller {
  close() {
    this.element.remove()
  }
}
