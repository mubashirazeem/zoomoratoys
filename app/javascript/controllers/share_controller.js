import { Controller } from "@hotwired/stimulus"

// Real sharing: the Web Share API where supported (mobile browsers, most
// desktop browsers), falling back to copying the link to the clipboard
// with a brief confirmation where it isn't.
export default class extends Controller {
  static targets = ["feedback"]
  static values = { title: String, text: String }

  async share() {
    const shareData = { title: this.titleValue, text: this.textValue, url: window.location.href }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
      } catch (error) {
        // AbortError means the person just closed the native share sheet —
        // not a real failure, nothing to report.
        if (error.name !== "AbortError") this.copyLink()
      }
    } else {
      this.copyLink()
    }
  }

  async copyLink() {
    await navigator.clipboard.writeText(window.location.href)
    this.showFeedback()
  }

  showFeedback() {
    if (!this.hasFeedbackTarget) return

    this.feedbackTarget.hidden = false
    clearTimeout(this.feedbackTimeout)
    this.feedbackTimeout = setTimeout(() => { this.feedbackTarget.hidden = true }, 2000)
  }
}
