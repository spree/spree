Spree.ready(function () {
  var $navLinks = $('.main-nav-bar .nav-link.dropdown-toggle')
  var $dropdownMenu = $('.main-nav-bar .dropdown-menu')
  var SHOW_CLASS = 'show'
  var DATA_TOGGLE_ATTR = 'data-toggle'
  var DATA_TOGGLE_VALUE = 'dropdown'

  function handleInOutNavLinks(event) {
    var $navLink = $(this)
    var $parent = $navLink.parent()
    var $dropdown = $navLink.next()

    if (event.type === 'mouseenter') {
      $navLink.removeAttr(DATA_TOGGLE_ATTR)
      $parent.addClass(SHOW_CLASS)
      $dropdown.addClass(SHOW_CLASS)
    } else if (event.type === 'mouseleave') {
      var isDropdownHovered = $dropdown.filter(':hover').length
      var isNavLinkHovered = $navLink.filter(':hover').length
      if (isDropdownHovered || isNavLinkHovered) {
        return
      }
      $navLink.attr(DATA_TOGGLE_ATTR, DATA_TOGGLE_VALUE)
      $parent.removeClass(SHOW_CLASS)
      $dropdown.removeClass(SHOW_CLASS)
    }
  }

  function handleOutDropdown() {
    var $dropdown = $(this)
    var isDropdownHovered = $dropdown.filter(':hover').length
    var isNavLinkHovered = $dropdown.prev().filter(':hover').length
    if (isDropdownHovered || isNavLinkHovered) {
      return
    }
    $dropdown.parent().removeClass(SHOW_CLASS)
    $dropdown.removeClass(SHOW_CLASS)
  }

  $navLinks.on('mouseenter mouseleave', handleInOutNavLinks);
  $dropdownMenu.on('mouseleave', handleOutDropdown)
})
