document.addEventListener('DOMContentLoaded', function() {
  var body = $('body')
  var modalBackdrop = $('#multi-backdrop')

  // Fail safe on screen resize
  var resizeTimer;
  window.addEventListener('resize', function() {
    document.body.classList.remove('modal-open', 'sidebar-open', 'contextualSideMenu-open');
    document.body.classList.add('resize-animation-stopper');
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function() {
      document.body.classList.remove('resize-animation-stopper');
    }, 400);
  });

  function closeAllMenus() {
    body.removeClass()
    body.addClass('admin')
    modalBackdrop.removeClass('show')
  }

  modalBackdrop.click(closeAllMenus)

  // Main Menu Functionality
  var sidebarOpen = $('#sidebar-open')
  var sidebarClose = $('#sidebar-close')
  var activeItem = $('#main-sidebar').find('.selected')

  activeItem.closest('.nav-sidebar').addClass('active-option')
  activeItem.closest('.nav-pills').addClass('in show')

  function openMenu() {
    closeAllMenus()
    body.addClass('sidebar-open modal-open')
    modalBackdrop.addClass('show')
  }
  sidebarOpen.click(openMenu)
  sidebarClose.click(closeAllMenus)

  // Contextual Sidebar Menu
  var contextualSidebarMenuToggle = $('#contextual-menu-toggle')
  var contextualSidebarMenuClose = $('#contextual-menu-close')

  function toggleContextualMenu() {
    if (document.body.classList.contains('contextualSideMenu-open')) {
      closeAllMenus()
    } else {
      closeAllMenus()
      body.addClass('contextualSideMenu-open modal-open')
      modalBackdrop.addClass('show')
    }
  }

  contextualSidebarMenuToggle.click(toggleContextualMenu)
  contextualSidebarMenuClose.click(toggleContextualMenu)
})
