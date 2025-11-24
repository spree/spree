import { Controller } from "@hotwired/stimulus";
import {
  computePosition,
  flip,
  shift,
  offset,
  autoUpdate,
} from "@floating-ui/dom";

export default class extends Controller {
  static targets = ["desktop", "mobile"];

  static values = {
    storageKey: { type: String, default: "spree_admin_sidebar_open" },
  };

  connect() {
    // Initialize dropdown tracking
    this.activeDropdown = null
    this.dropdownCleanup = null
    this.submenuHoverHandlers = new Map()
    this.hideTimeout = null

    // Disable transitions during initial load to prevent animation flash
    this.element.classList.add("sidebar-no-transition");

    // Restore saved state for desktop sidebar (default is open/expanded)
    const savedState = localStorage.getItem(this.storageKeyValue);

    // Only collapse if explicitly saved as false
    if (savedState === "false") {
      this.element.classList.add("sidebar-collapsed");
      this.setupCollapsedSubmenuHandlers();
    } else {
      // Explicitly ensure it's not collapsed (default is expanded)
      this.element.classList.remove("sidebar-collapsed");
    }

    // Re-enable transitions after initial state is set
    requestAnimationFrame(() => {
      this.element.classList.remove("sidebar-no-transition");
    });
  }

  disconnect() {
    // Clear any pending hide timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    this.cleanupSubmenuHandlers();
    if (this.dropdownCleanup) {
      this.dropdownCleanup();
      this.dropdownCleanup = null;
    }
  }

  toggle() {
    this.element.classList.toggle("sidebar-collapsed");
    const isCollapsed = this.element.classList.contains("sidebar-collapsed");
    localStorage.setItem(this.storageKeyValue, String(!isCollapsed));

    // Setup or cleanup submenu handlers based on state
    if (isCollapsed) {
      this.setupCollapsedSubmenuHandlers();
    } else {
      this.cleanupSubmenuHandlers();
    }
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

  setupCollapsedSubmenuHandlers() {
    const sidebar = document.querySelector('#main-sidebar');
    if (!sidebar) return;

    // Find all dropdown submenus
    const dropdowns = sidebar.querySelectorAll('.nav-submenu-dropdown');

    dropdowns.forEach(dropdown => {
      // Find the associated nav-item (previous sibling, skipping the regular nav-submenu)
      let navItem = dropdown.previousElementSibling;

      // Skip over the regular .nav-submenu to get to the .nav-item
      while (navItem && navItem.classList.contains('nav-submenu')) {
        navItem = navItem.previousElementSibling;
      }

      if (!navItem || !navItem.classList.contains('nav-item')) return;

      const showHandler = () => this.showSubmenuFloating(navItem, dropdown);
      const hideHandler = () => this.scheduleHideSubmenu();

      navItem.addEventListener('mouseenter', showHandler);
      navItem.addEventListener('mouseleave', hideHandler);
      dropdown.addEventListener('mouseenter', showHandler);
      dropdown.addEventListener('mouseleave', hideHandler);

      this.submenuHoverHandlers.set(navItem, { showHandler, hideHandler, dropdown });
    });
  }

  cleanupSubmenuHandlers() {
    this.submenuHoverHandlers.forEach(({ showHandler, hideHandler, dropdown }, navItem) => {
      navItem.removeEventListener('mouseenter', showHandler);
      navItem.removeEventListener('mouseleave', hideHandler);
      dropdown.removeEventListener('mouseenter', showHandler);
      dropdown.removeEventListener('mouseleave', hideHandler);
    });
    this.submenuHoverHandlers.clear();

    // Hide active dropdown if any
    if (this.activeDropdown) {
      this.hideSubmenuFloating();
    }
  }

  showSubmenuFloating(navItem, dropdown) {
    // Cancel any pending hide
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    // If showing same dropdown, return
    if (this.activeDropdown === dropdown) {
      return;
    }

    // Hide any currently active dropdown
    if (this.activeDropdown) {
      this.hideSubmenuFloating();
    }

    // Store reference
    this.activeDropdown = dropdown;

    // Move dropdown to body for proper positioning (to avoid sidebar overflow clipping)
    if (dropdown.parentNode !== document.body) {
      dropdown._originalParent = dropdown.parentNode;
      dropdown._originalNextSibling = dropdown.nextSibling;
      document.body.appendChild(dropdown);
    }

    // Show dropdown
    dropdown.classList.remove('d-none');

    // Style dropdown items
    dropdown.querySelectorAll('.nav-link').forEach((item, index) => {
      item.classList.add('dropdown-item');
      if (index > 0) {
        item.classList.add('mt-1');
      }
    });

    // Position using Floating UI
    if (this.dropdownCleanup) {
      this.dropdownCleanup();
    }

    this.dropdownCleanup = autoUpdate(navItem, dropdown, () => {
      computePosition(navItem, dropdown, {
        placement: 'right-start',
        middleware: [
          offset(8),
          flip(),
          shift({ padding: 8 }),
        ],
      }).then(({ x, y }) => {
        Object.assign(dropdown.style, {
          left: `${x}px`,
          top: `${y}px`,
        });
      });
    });
  }

  scheduleHideSubmenu() {
    // Clear any existing timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }

    // Schedule hide with delay to allow mouse to move to submenu
    this.hideTimeout = setTimeout(() => {
      this.hideSubmenuFloating();
      this.hideTimeout = null;
    }, 150); // 150ms grace period
  }

  hideSubmenuFloating() {
    if (!this.activeDropdown) return;

    // Stop auto-update
    if (this.dropdownCleanup) {
      this.dropdownCleanup();
      this.dropdownCleanup = null;
    }

    // Hide dropdown
    this.activeDropdown.classList.add('d-none');

    // Restore dropdown to original position in sidebar
    if (this.activeDropdown._originalParent) {
      if (this.activeDropdown._originalNextSibling) {
        this.activeDropdown._originalParent.insertBefore(
          this.activeDropdown,
          this.activeDropdown._originalNextSibling
        );
      } else {
        this.activeDropdown._originalParent.appendChild(this.activeDropdown);
      }
      this.activeDropdown._originalParent = null;
      this.activeDropdown._originalNextSibling = null;
    }

    // Clear reference
    this.activeDropdown = null;
  }
}
