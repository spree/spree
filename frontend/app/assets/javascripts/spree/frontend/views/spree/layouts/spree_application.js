Spree.ready(function ($) {
  document.getElementById('overlay').addEventListener('click', function () {
    var noProductElement = document.getElementById('no-product-available')
    document.getElementById("overlay").classList.remove('shown');
    document.getElementById("search-dropdown").classList.remove('shown');
    document.querySelector('.header-spree').classList.remove('above-overlay')
    if (noProductElement) noProductElement.classList.remove('shown');
  }, false);

  document.onkeydown = function(evt) {
    var searchMenuElement = document.getElementsByClassName("navbar-right-search-menu")

    if (searchMenuElement.length === 1) {
      evt = evt || window.event;
      var isEscape = false;
      var isOpenSearchInput = searchMenuElement[0].classList.contains("shown")

      if (isOpenSearchInput)
        return;

      if ("key" in evt) {
        isEscape = (evt.key === "Escape" || evt.key === "Esc");
      } else {
        isEscape = (evt.keyCode === 27);
      }
      if (isEscape) {
        document.querySelector(".navbar-right-dropdown-toggle").blur();
        document.getElementById("overlay").classList.remove('shown');
        document.querySelector('.header-spree').classList.remove('above-overlay')
        document.getElementById("search-dropdown").classList.remove('shown');
        $('.hide-on-esc').toggleClass('shown', false)
      }
    }
  };

  var searchDropdown = document.getElementById('search-dropdown')
  var navBarCategoryLinks = document.getElementsByClassName('main-nav-bar-category-links')
  var navBarCategoryButtons = document.getElementsByClassName('main-nav-bar-category-button')
  var navBarCategoryImages = document.getElementsByClassName('category-image')
  var navBarAccountIcon = [document.getElementById('account-button')]
  var navBarCartIcon = [document.getElementById('link-to-cart')]
  var spreeLogoImage = document.getElementsByClassName('header-spree-fluid-logo')
  var spreeMobileNavs = document.getElementsByClassName('mobile-navigation-list-item')
  var navbarLinks = [
    navBarCategoryLinks,
    navBarCategoryButtons,
    navBarCategoryImages,
    navBarAccountIcon,
    navBarCartIcon,
    spreeLogoImage,
    spreeMobileNavs
  ]

  if (searchDropdown !== null) {
    $.each(navbarLinks, function(index, navbarElements) {
      $.each(navbarElements, function(index, navBarCategoryLink) {
        navBarCategoryLink.addEventListener('click', function () {
          document.getElementById('overlay').classList.remove('shown');
          searchDropdown.classList.remove('shown');
          document.querySelector('.header-spree').classList.remove('above-overlay')
        });
      });
    });
  };
});
