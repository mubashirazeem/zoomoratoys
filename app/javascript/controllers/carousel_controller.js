import { Controller } from "@hotwired/stimulus"

// Product rail: a native scroll-snap track with smooth arrow buttons, a
// buttery drag-to-scroll for mouse/trackpad users (with a light momentum
// fling on release), and edge-fade masks + disabled arrow states that
// reflect how much more content is off-screen in each direction. Touch
// devices keep the browser's own (better) native momentum scrolling — the
// custom drag only fills the gap that touch doesn't have: mouse dragging.
export default class extends Controller {
  static targets = ["track", "prev", "next"]

  connect() {
    this.onScroll = this.onScroll.bind(this)
    this.onPointerDown = this.onPointerDown.bind(this)
    this.onPointerMove = this.onPointerMove.bind(this)
    this.onPointerUp = this.onPointerUp.bind(this)

    this.trackTarget.addEventListener("scroll", this.onScroll, { passive: true })
    this.trackTarget.addEventListener("pointerdown", this.onPointerDown)
    window.addEventListener("resize", this.onScroll)
    this.updateEdges()
  }

  disconnect() {
    this.trackTarget.removeEventListener("scroll", this.onScroll)
    this.trackTarget.removeEventListener("pointerdown", this.onPointerDown)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
    window.removeEventListener("resize", this.onScroll)
    if (this.edgeRaf) cancelAnimationFrame(this.edgeRaf)
    if (this.momentumRaf) cancelAnimationFrame(this.momentumRaf)
  }

  next() {
    this.scrollByAmount(1)
  }

  prev() {
    this.scrollByAmount(-1)
  }

  scrollByAmount(direction) {
    const track = this.trackTarget
    const amount = track.clientWidth * 0.8 * direction
    track.scrollBy({ left: amount, behavior: "smooth" })
  }

  // ---- edge state (drives the fade mask + disabled arrows) ----

  onScroll() {
    if (this.edgeRaf) return
    this.edgeRaf = requestAnimationFrame(() => {
      this.edgeRaf = null
      this.updateEdges()
    })
  }

  updateEdges() {
    const track = this.trackTarget
    const max = track.scrollWidth - track.clientWidth
    const atStart = track.scrollLeft <= 4
    const atEnd = track.scrollLeft >= max - 4
    this.element.classList.toggle("is-at-start", atStart)
    this.element.classList.toggle("is-at-end", atEnd)
    if (this.hasPrevTarget) this.prevTarget.disabled = atStart
    if (this.hasNextTarget) this.nextTarget.disabled = atEnd
  }

  // ---- drag-to-scroll with momentum (mouse/trackpad only) ----

  onPointerDown(event) {
    if (event.pointerType === "touch") return
    if (this.momentumRaf) cancelAnimationFrame(this.momentumRaf)

    this.dragging = true
    this.dragMoved = false
    this.startX = event.clientX
    this.startScroll = this.trackTarget.scrollLeft
    this.lastX = event.clientX
    this.lastT = performance.now()
    this.velocity = 0
    this.trackTarget.classList.add("is-dragging")

    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp, { once: true })
  }

  onPointerMove(event) {
    if (!this.dragging) return
    const delta = event.clientX - this.startX
    if (Math.abs(delta) > 4) this.dragMoved = true
    this.trackTarget.scrollLeft = this.startScroll - delta

    const now = performance.now()
    const dt = now - this.lastT
    if (dt > 0) {
      this.velocity = (this.lastX - event.clientX) / dt
      this.lastX = event.clientX
      this.lastT = now
    }
  }

  onPointerUp() {
    this.dragging = false
    this.trackTarget.classList.remove("is-dragging")
    window.removeEventListener("pointermove", this.onPointerMove)

    if (this.dragMoved) {
      // Releasing a real drag over a product card shouldn't also follow its
      // link — swallow the very next click the browser would otherwise fire.
      const swallow = (event) => {
        event.preventDefault()
        event.stopPropagation()
      }
      this.trackTarget.addEventListener("click", swallow, { capture: true, once: true })
      this.applyMomentum()
    }
  }

  applyMomentum() {
    let velocity = this.velocity * 16
    const friction = 0.94
    const step = () => {
      if (Math.abs(velocity) < 0.5) return
      this.trackTarget.scrollLeft += velocity
      velocity *= friction
      this.momentumRaf = requestAnimationFrame(step)
    }
    this.momentumRaf = requestAnimationFrame(step)
  }
}
