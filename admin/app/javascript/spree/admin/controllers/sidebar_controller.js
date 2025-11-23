import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["desktop", "mobile"];

  static values = {
    storageKey: { type: String, default: "spree_admin_sidebar_open" },
  };

  connect() {
    // Disable transitions during initial load to prevent animation flash
    this.element.classList.add("sidebar-no-transition");

    // Restore saved state for desktop sidebar (default is open/expanded)
    const savedState = localStorage.getItem(this.storageKeyValue);

    // Only collapse if explicitly saved as false
    if (savedState === "false") {
      this.element.classList.add("sidebar-collapsed");
    } else {
      // Explicitly ensure it's not collapsed (default is expanded)
      this.element.classList.remove("sidebar-collapsed");
    }

    // Re-enable transitions after initial state is set
    requestAnimationFrame(() => {
      this.element.classList.remove("sidebar-no-transition");
    });
  }

  toggle() {
    this.element.classList.toggle("sidebar-collapsed");
    const isCollapsed = this.element.classList.contains("sidebar-collapsed");
    localStorage.setItem(this.storageKeyValue, String(!isCollapsed));
  }

  openMobile() {
    if (this.hasMobileTarget) {
      this.mobileTarget.classList.add("sidebar-mobile-open");
    }
  }

  closeMobile() {
    if (this.hasMobileTarget) {
      this.mobileTarget.classList.remove("sidebar-mobile-open");
    }
  }
}
