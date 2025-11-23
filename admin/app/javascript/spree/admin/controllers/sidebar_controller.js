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
    // Initialize submenu tracking
    this.activeSubmenu = null
    this.activeSubmenuClone = null
    this.submenuCleanup = null
    this.submenuHoverHandlers = new Map()
    this.submenuClones = new Map()
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
    if (this.submenuCleanup) {
      this.submenuCleanup();
      this.submenuCleanup = null;
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

    // Find all nav items with submenus
    const navItemsWithSubmenu = sidebar.querySelectorAll('.nav-item:has(+ .nav-submenu)');

    navItemsWithSubmenu.forEach(navLink => {
      const submenu = navLink.nextElementSibling;
      if (!submenu || !submenu.classList.contains('nav-submenu')) return;

      const showHandler = () => this.showSubmenuFloating(navLink, submenu);
      const hideHandler = () => this.scheduleHideSubmenu();

      navLink.addEventListener('mouseenter', showHandler);
      navLink.addEventListener('mouseleave', hideHandler);
      submenu.addEventListener('mouseenter', showHandler);
      submenu.addEventListener('mouseleave', hideHandler);

      this.submenuHoverHandlers.set(navLink, { showHandler, hideHandler, submenu });
    });
  }

  cleanupSubmenuHandlers() {
    this.submenuHoverHandlers.forEach(({ showHandler, hideHandler, submenu }, navLink) => {
      navLink.removeEventListener('mouseenter', showHandler);
      navLink.removeEventListener('mouseleave', hideHandler);
      submenu.removeEventListener('mouseenter', showHandler);
      submenu.removeEventListener('mouseleave', hideHandler);
    });
    this.submenuHoverHandlers.clear();

    // Hide active submenu if any
    if (this.activeSubmenuClone) {
      this.hideSubmenuFloating();
    }

    // Clean up all clones
    this.submenuClones.forEach(clone => {
      if (clone && clone.parentNode) {
        clone.remove();
      }
    });
    this.submenuClones.clear();
  }

  showSubmenuFloating(navLink, submenu) {

    // Cancel any pending hide
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    // If showing same submenu, return
    if (this.activeSubmenu === submenu && this.activeSubmenuClone) {
      return;
    }

    // Hide any currently active submenu
    if (this.activeSubmenuClone) {
      this.hideSubmenuFloating();
    }

    // Create clone of submenu
    const submenuClone = submenu.cloneNode(true);

    // Store references
    this.activeSubmenu = submenu;
    this.activeSubmenuClone = submenuClone;
    this.submenuClones.set(submenu, submenuClone);

    // Append clone to body
    document.body.appendChild(submenuClone);

    // Style clone as floating dropdown
    submenuClone.classList.remove('d-none');
    submenuClone.classList.add('dropdown-container');

    // Add the main nav-link as the first item in the submenu (only if not already added)
    const existingClone = submenuClone.querySelector('.dropdown-item.nav-link-clone');
    if (!existingClone) {
      const mainNavLinkClone = navLink.querySelector('.nav-link').cloneNode(true);
      mainNavLinkClone.classList.add('dropdown-item', 'nav-link-clone');
      mainNavLinkClone.classList.remove('nav-link');
      // Remove the icon from the cloned nav link
      const icon = mainNavLinkClone.querySelector('.ti');
      if (icon) {
        icon.remove();
      }

      // Insert at the beginning of the submenu
      submenuClone.insertBefore(mainNavLinkClone, submenuClone.firstChild);
    }

    submenuClone.querySelectorAll('.nav-link').forEach((item, index) => {
      item.classList.add('dropdown-item');
      if (index > 0) {
        item.classList.add('mt-1');
      }
    });

    // Add hover handlers to clone
    submenuClone.addEventListener('mouseenter', () => {
      if (this.hideTimeout) {
        clearTimeout(this.hideTimeout);
        this.hideTimeout = null;
      }
    });
    submenuClone.addEventListener('mouseleave', () => this.scheduleHideSubmenu());

    // Position using Floating UI
    if (this.submenuCleanup) {
      this.submenuCleanup();
    }

    this.submenuCleanup = autoUpdate(navLink, submenuClone, () => {
      computePosition(navLink, submenuClone, {
        placement: 'right-start',
        middleware: [
          offset(8),
          flip(),
          shift({ padding: 8 }),
        ],
      }).then(({ x, y }) => {
        Object.assign(submenuClone.style, {
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
    if (!this.activeSubmenuClone) return;

    // Stop auto-update
    if (this.submenuCleanup) {
      this.submenuCleanup();
      this.submenuCleanup = null;
    }

    // Remove clone from DOM
    if (this.activeSubmenuClone.parentNode) {
      this.activeSubmenuClone.remove();
    }

    // Clear references
    if (this.activeSubmenu) {
      this.submenuClones.delete(this.activeSubmenu);
    }
    this.activeSubmenu = null;
    this.activeSubmenuClone = null;
  }
}
