import { Controller } from "@hotwired/stimulus"

// True 3D hero carousel: slides live as faces on a perspective "cube" that
// physically turns to bring the next one to the front — not a crossfade or
// a flat sliding track. Face geometry (radius/perspective) is measured from
// the element's real width so the depth looks proportional at any viewport
// size. Each face also gets a slow Ken Burns zoom and a staggered text
// reveal, with its text sitting on its own floating Z-depth layer so it
// visibly parallaxes against the photo as the cube turns. The whole scene
// tilts gently toward the cursor (fine-pointer devices only, skipped under
// reduced motion). A full-width segmented bar doubles as progress and a
// click-to-jump scrubber. Hovering or focusing the slider pauses autoplay;
// touch users can swipe; arrow keys navigate when the slider has focus.
export default class extends Controller {
  static targets = ["scene", "cube", "tilt", "face", "segment", "segmentFill"]
  static values = { interval: { type: Number, default: 6000 } }

  tiltMax = 6

  connect() {
    this.element.classList.add("js-ready")
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.canTilt = !this.reduceMotion && window.matchMedia("(pointer: fine)").matches

    this.index = 0
    this.baseRotation = 0
    this.tiltX = 0
    this.tiltY = 0

    this.layout()
    this.applyTiltTransform()
    this.activateFace(0)
    this.updateSegments()
    this.start()

    requestAnimationFrame(() => this.element.classList.add("is-ready"))

    this.onResize = this.debounce(() => this.layout(), 150)
    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchEnd = this.onTouchEnd.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    window.addEventListener("resize", this.onResize)
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd, { passive: true })
    this.element.addEventListener("keydown", this.onKeydown)

    if (this.canTilt) {
      this.onMouseMove = this.onMouseMove.bind(this)
      this.onMouseLeave = this.onMouseLeave.bind(this)
      this.element.addEventListener("mousemove", this.onMouseMove)
      this.element.addEventListener("mouseleave", this.onMouseLeave)
    }
  }

  disconnect() {
    this.stop()
    window.removeEventListener("resize", this.onResize)
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("keydown", this.onKeydown)
    if (this.onMouseMove) this.element.removeEventListener("mousemove", this.onMouseMove)
    if (this.onMouseLeave) this.element.removeEventListener("mouseleave", this.onMouseLeave)
    if (this.rafId) cancelAnimationFrame(this.rafId)
  }

  // ---- 3D geometry ----

  layout() {
    const width = this.element.getBoundingClientRect().width
    const len = this.faceTargets.length
    this.faceAngle = 360 / len
    this.radius = (width / 2) / Math.tan(Math.PI / len)
    this.sceneTarget.style.perspective = `${Math.round(width * 1.3)}px`
    this.faceTargets.forEach((face, n) => {
      face.style.transform = `rotateY(${n * this.faceAngle}deg) translateZ(${this.radius}px)`
    })
    this.applyCubeTransform()
  }

  applyCubeTransform() {
    this.cubeTarget.style.transform = `translateZ(${-this.radius}px) rotateY(${this.baseRotation}deg)`
  }

  applyTiltTransform() {
    this.tiltTarget.style.transform = `rotateX(${this.tiltX}deg) rotateY(${this.tiltY}deg)`
  }

  // ---- autoplay ----

  start() {
    this.stop()
    this.timer = setInterval(() => this.advance(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
  }

  pause() {
    this.element.classList.add("is-paused")
    this.stop()
  }

  resume() {
    this.element.classList.remove("is-paused")
    this.start()
  }

  // ---- navigation ----

  advance() {
    this.show(this.index + 1)
  }

  next() {
    this.show(this.index + 1)
    this.start()
  }

  prev() {
    this.show(this.index - 1)
    this.start()
  }

  goto(event) {
    this.show(Number(event.currentTarget.dataset.index))
    this.start()
  }

  show(i) {
    const len = this.faceTargets.length
    const newIndex = ((i % len) + len) % len

    // Accumulate rotation by the shortest angular step rather than jumping
    // to an absolute angle, so the cube always turns the short way round
    // (advance/prev/goto all feel like a single consistent swing) instead
    // of occasionally spinning the long way when CSS interpolates rotateY.
    let steps = newIndex - this.index
    if (steps > len / 2) steps -= len
    if (steps < -len / 2) steps += len

    this.baseRotation -= steps * this.faceAngle
    this.index = newIndex
    this.applyCubeTransform()
    this.activateFace(this.index)
    this.updateSegments()
  }

  activateFace(activeIndex) {
    this.faceTargets.forEach((face) => face.classList.remove("is-active"))
    // Force a reflow so the Ken Burns zoom and text reveal restart cleanly
    // when a face becomes active again, instead of silently no-op'ing
    // within the same JS tick.
    void this.element.offsetWidth
    this.faceTargets.forEach((face, n) => {
      const active = n === activeIndex
      face.classList.toggle("is-active", active)
      face.setAttribute("aria-hidden", active ? "false" : "true")
      face.style.pointerEvents = active ? "" : "none"
    })
  }

  updateSegments() {
    this.segmentTargets.forEach((segment, n) => {
      segment.setAttribute("aria-current", n === this.index ? "true" : "false")
      const fill = this.segmentFillTargets[n]
      fill.style.animation = "none"
      if (n < this.index) {
        fill.style.width = "100%"
      } else if (n === this.index) {
        fill.style.width = "0%"
        void fill.offsetWidth
        fill.style.animation = `heroProgress ${this.intervalValue}ms linear forwards`
      } else {
        fill.style.width = "0%"
      }
    })
  }

  // ---- cursor tilt ----

  onMouseMove(event) {
    if (this.rafId) return
    this.rafId = requestAnimationFrame(() => {
      this.rafId = null
      const rect = this.element.getBoundingClientRect()
      const nx = ((event.clientX - rect.left) / rect.width) * 2 - 1
      const ny = ((event.clientY - rect.top) / rect.height) * 2 - 1
      this.tiltX = -ny * this.tiltMax
      this.tiltY = nx * this.tiltMax
      this.applyTiltTransform()
    })
  }

  onMouseLeave() {
    this.tiltX = 0
    this.tiltY = 0
    this.applyTiltTransform()
  }

  // ---- touch + keyboard ----

  onTouchStart(event) {
    this.touchStartX = event.changedTouches[0].clientX
  }

  onTouchEnd(event) {
    if (this.touchStartX == null) return
    const delta = event.changedTouches[0].clientX - this.touchStartX
    this.touchStartX = null
    if (Math.abs(delta) < 40) return
    if (delta < 0) this.next()
    else this.prev()
  }

  onKeydown(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    }
  }

  debounce(fn, wait) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn(...args), wait)
    }
  }
}
