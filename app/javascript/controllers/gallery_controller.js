import { Controller } from "@hotwired/stimulus"

// Product image gallery: thumbnail swap, a cursor-follow zoom lens on
// hover (desktop, hover-capable pointers only), and a full-screen lightbox
// for a closer look. Clicking/tapping the main image opens the lightbox;
// clicking/tapping the lightbox image toggles a 2x zoom centered on that
// point — one interaction covers both mouse and touch instead of separate
// drag/pinch gesture code for each.
export default class extends Controller {
  static targets = [
    "main", "thumb", "lens",
    "lightbox", "lightboxImage", "lightboxThumb", "counter"
  ]

  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.canHover = window.matchMedia("(hover: hover) and (pointer: fine)").matches
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  // ---- Thumbnail swap ----
  select(event) {
    this.showImage(this.thumbTargets.indexOf(event.currentTarget))
  }

  showImage(index) {
    const thumb = this.thumbTargets[index]
    if (!thumb) return

    const fullSrc = thumb.dataset.fullSrc || thumb.querySelector("img")?.src
    if (fullSrc) this.mainTarget.src = fullSrc
    if (this.hasLensTarget) this.lensTarget.style.backgroundImage = `url(${thumb.dataset.zoomSrc || fullSrc})`

    this.thumbTargets.forEach((t, i) => {
      t.classList.toggle("border-red-600", i === index)
      t.classList.toggle("border-grey-200", i !== index)
    })

    this.indexValue = index
  }

  // ---- Hover zoom lens (desktop only) ----
  zoomEnter() {
    if (!this.canHover || !this.hasLensTarget) return
    this.lensTarget.style.opacity = "1"
  }

  zoomLeave() {
    if (!this.hasLensTarget) return
    this.lensTarget.style.opacity = "0"
  }

  zoomMove(event) {
    if (!this.canHover || !this.hasLensTarget) return
    const rect = event.currentTarget.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * 100
    const y = ((event.clientY - rect.top) / rect.height) * 100
    this.lensTarget.style.backgroundPosition = `${x}% ${y}%`
  }

  // ---- Lightbox ----
  openLightbox() {
    if (!this.hasLightboxTarget) return
    this.triggerElement = document.activeElement
    this.lightboxTarget.classList.remove("hidden")
    this.lightboxTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.handleKeydown)
    this.syncLightbox(this.indexValue)
    this.lightboxTarget.focus()
  }

  closeLightbox() {
    if (!this.hasLightboxTarget) return
    this.lightboxTarget.classList.add("hidden")
    this.lightboxTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.handleKeydown)
    this.resetLightboxZoom()
    this.triggerElement?.focus()
  }

  prevImage() {
    const count = this.thumbTargets.length
    this.syncLightbox((this.indexValue - 1 + count) % count, true)
  }

  nextImage() {
    const count = this.thumbTargets.length
    this.syncLightbox((this.indexValue + 1) % count, true)
  }

  selectLightbox(event) {
    this.syncLightbox(this.lightboxThumbTargets.indexOf(event.currentTarget), true)
  }

  syncLightbox(index, alsoUpdateMain = false) {
    const thumb = this.thumbTargets[index]
    if (!thumb) return

    if (this.hasLightboxImageTarget) {
      this.lightboxImageTarget.src = thumb.dataset.zoomSrc || thumb.dataset.fullSrc
      this.resetLightboxZoom()
    }
    if (this.hasCounterTarget) this.counterTarget.textContent = `${index + 1} / ${this.thumbTargets.length}`

    this.lightboxThumbTargets.forEach((t, i) => {
      t.classList.toggle("border-red-600", i === index)
      t.classList.toggle("border-white/30", i !== index)
    })

    this.indexValue = index
    if (alsoUpdateMain) this.showImage(index)
  }

  toggleZoom(event) {
    if (!this.hasLightboxImageTarget) return

    const zoomed = this.lightboxImageTarget.classList.toggle("scale-[2]")
    if (zoomed) {
      const rect = event.currentTarget.getBoundingClientRect()
      const x = ((event.clientX - rect.left) / rect.width) * 100
      const y = ((event.clientY - rect.top) / rect.height) * 100
      this.lightboxImageTarget.style.transformOrigin = `${x}% ${y}%`
      this.lightboxImageTarget.classList.replace("cursor-zoom-in", "cursor-zoom-out")
    } else {
      this.resetLightboxZoom()
    }
  }

  resetLightboxZoom() {
    if (!this.hasLightboxImageTarget) return
    this.lightboxImageTarget.classList.remove("scale-[2]")
    this.lightboxImageTarget.classList.replace("cursor-zoom-out", "cursor-zoom-in")
    this.lightboxImageTarget.style.transformOrigin = "center"
  }

  handleKeydown(event) {
    if (event.key === "Escape") return this.closeLightbox()
    if (event.key === "ArrowLeft") return this.prevImage()
    if (event.key === "ArrowRight") return this.nextImage()
  }
}
