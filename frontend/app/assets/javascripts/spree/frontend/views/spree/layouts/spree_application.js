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
});
