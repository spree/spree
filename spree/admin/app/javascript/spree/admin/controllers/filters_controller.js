import { Controller } from "@hotwired/stimulus";
import DOMPurify from "dompurify"

export default class extends Controller {
  static targets = ["input", "badgesContainer", "badgeTemplate"];

  static values = {
    url: { type: String }
  };

  connect() {
    this.inputTargets.forEach((input) => {
      this.createBadgeFor(input);
    });
  }

  createBadgeFor(input, tomSelect = false) {
    if (
      input.tagName === "SELECT" &&
      input.dataset.selectTarget &&
      !input.classList.contains("tomselected")
    ) {
      input.addEventListener("tomSelectInitialized", () => {
        this.createBadgeFor(input, true);
      });
    } else if (input.value !== null && input.value.length !== 0) {
      let labelEl;
      if (tomSelect) {
        labelEl = document.querySelector(`label[for="${input.id}-ts-control"]`);
      } else {
        labelEl = document.querySelector(`label[for="${input.id}"]`);
      }

      let label;
      if (labelEl) {
        label = labelEl.textContent;
      } else if (input.dataset.badgeName) {
        label = input.dataset.badgeName;
      } else {
        label = input.placeholder;
      }

      let ransackValue;
      if (input.tagName === "SELECT") {
        ransackValue = Array.from(input.selectedOptions)
          .map((option) => option.text)
          .join(", ");
      } else {
        ransackValue = input.value;
      }

      label = DOMPurify.sanitize(`${label.trim()}: ${ransackValue.trim()}`);

      const newUrl = this.urlValue ? new URL(this.urlValue) : new URL(window.location.href);
      const newSearchParams = newUrl.searchParams;
      newSearchParams.delete(input.name);
      newUrl.search = newSearchParams.toString();

      const filterHTML = this.badgeTemplateTarget.innerHTML
        .replace(/LABEL/g, label)
        .replace(/DELETE_URL/g, newUrl.toString());

      this.badgesContainerTarget.insertAdjacentHTML("beforeend", filterHTML);
    }
  }
}
