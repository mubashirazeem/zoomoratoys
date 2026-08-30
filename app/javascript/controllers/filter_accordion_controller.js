import { Controller } from "@hotwired/stimulus"

// Sidebar filter sections (Categories/Color/Availability/Price) are plain
// <details> elements — independent by default, so opening one leaves the
// others open too. This closes every other section the instant one opens,
// so only one is ever expanded at a time (native <details name="">
// exclusive-accordion support needs a newer browser than this site's own
// floor — see ApplicationController's allow_browser — so this is done in
// JS instead, to actually work for every visitor).
export default class extends Controller {
  static targets = ["section"]

  close(event) {
    if (!event.target.open) return

    this.sectionTargets.forEach((section) => {
      if (section !== event.target) section.open = false
    })
  }
}
