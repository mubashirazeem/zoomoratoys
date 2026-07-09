import { Controller } from "@hotwired/stimulus"

// Product image gallery: clicking a thumbnail swaps the main image and marks
// the active thumbnail. Reads the source from the thumbnail's own <img> so no
// duplicate asset path is needed in the markup.
export default class extends Controller {
  static targets = ["main", "thumb"]

  select(event) {
    const thumb = event.currentTarget
    const img = thumb.querySelector("img")
    if (img) this.mainTarget.src = img.src

    this.thumbTargets.forEach((t) => {
      const active = t === thumb
      t.classList.toggle("border-red-600", active)
      t.classList.toggle("border-grey-200", !active)
    })
  }
}
