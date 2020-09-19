Spree.ready(function () {
  var $navLinks = $('.main-nav-bar .nav-link.dropdown-toggle')
  var $dropdownMenu = $('.main-nav-bar .dropdown-menu')
  var SHOW_CLASS = 'show'
  var DATA_TOGGLE_ATTR = 'data-toggle'
  var DATA_TOGGLE_VALUE = 'dropdown'

  function handleMouseInOutNavLinks(event) {
    var $navLink = $(this)
    var $parent = $navLink.parent()
    var $dropdown = $navLink.next()
    var eventType = event.type

    if (eventType === 'mouseenter') {
      $navLink.removeAttr(DATA_TOGGLE_ATTR)
      $parent.addClass(SHOW_CLASS)
      $dropdown.addClass(SHOW_CLASS)
    } else if (eventType === 'mouseleave') {
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

  function handleFocusinNavLink() {
    var $navLink = $(this)
    var $parent = $navLink.parent()
    var $dropdown = $navLink.next()

    $parent.addClass(SHOW_CLASS)
    $dropdownMenu.removeClass(SHOW_CLASS)
    $dropdown.addClass(SHOW_CLASS)
  }

  function handleFocusoutNavLink() {
    var $navLink = $(this)
    var $parent = $navLink.parent()
    var $dropdown = $navLink.next()

    setTimeout(function() {
      var dropdownHasActiveElement = $.contains($dropdown[0], document.activeElement)

      if (!dropdownHasActiveElement) {
        $parent.removeClass(SHOW_CLASS)
        $dropdown.removeClass(SHOW_CLASS)
      }
    }, 0)

  }

  function handleMouseleaveDropdown() {
    var $dropdown = $(this)
    var isDropdownHovered = $dropdown.filter(':hover').length
    var isNavLinkHovered = $dropdown.prev().filter(':hover').length
    if (isDropdownHovered || isNavLinkHovered) {
      return
    }
    $dropdown.parent().removeClass(SHOW_CLASS)
    $dropdown.removeClass(SHOW_CLASS)
  }

  function handleFocusoutDropdownItems() {
    var $dropdownLink = $(this)
    setTimeout(function() {
      var $parentDropdown = $dropdownLink.parents('.dropdown-menu')
      var $navLink = $parentDropdown.parent()
      var parentHasActiveElement = $.contains($parentDropdown[0], document.activeElement)

      if (!parentHasActiveElement) {
        $navLink.removeClass(SHOW_CLASS)
        $parentDropdown.removeClass(SHOW_CLASS)
      }
    }, 0)
  }

  $navLinks.on('mouseenter mouseleave', handleMouseInOutNavLinks);
  $navLinks.on('focusin', handleFocusinNavLink)
  $navLinks.on('focusout', handleFocusoutNavLink)
  $dropdownMenu.on('mouseleave', handleMouseleaveDropdown)
  $dropdownMenu.on('focusout', '.dropdown-item', handleFocusoutDropdownItems)
})
