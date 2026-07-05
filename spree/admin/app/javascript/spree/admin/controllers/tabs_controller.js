import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    activeTabClass: { type: String, default: "active" }
  }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget);
    this.showTab(index);
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      const active = i === index;
      tab.classList.toggle(this.activeTabClassValue, active);
      this.panelTargets[i].hidden = !active;
    });
  }
}