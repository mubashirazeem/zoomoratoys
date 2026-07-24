import { Controller } from "@hotwired/stimulus"

// Fills the real shipping fields from a real saved Address's data when
// picked — no server round-trip needed, the data is already on the page.
export default class extends Controller {
  static targets = ["radio", "name", "phone", "line1", "line2", "city", "emirate"]

  // No auto-fill on connect: the fields are already server-rendered with
  // the right values (typed params on a validation-error re-render take
  // priority over the default address) — re-applying here on load would
  // clobber a user's in-progress edits after an error re-render.
  fill(event) {
    this.apply(JSON.parse(event.currentTarget.dataset.address))
  }

  clear() {
    this.apply({ name: "", phone: "", line1: "", line2: "", city: "", emirate: "" })
  }

  apply(address) {
    if (this.hasNameTarget) this.nameTarget.value = address.name || ""
    if (this.hasPhoneTarget) this.phoneTarget.value = address.phone || ""
    if (this.hasLine1Target) this.line1Target.value = address.line1 || ""
    if (this.hasLine2Target) this.line2Target.value = address.line2 || ""
    if (this.hasCityTarget) this.cityTarget.value = address.city || ""
    if (this.hasEmirateTarget) this.emirateTarget.value = address.emirate || ""
  }
}
