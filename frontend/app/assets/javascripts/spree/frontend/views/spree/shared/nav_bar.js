$(document).ready(function() {
  var searchIcons = document.querySelectorAll('#nav-bar .search-icons')[0]
  var searchDropdown = document.getElementById('search-dropdown')

  if (searchIcons !== undefined) {
    searchIcons.addEventListener(
      'click',
      toggleSearchBar,
      false
    )
  }

  function toggleSearchBar() {
    if (searchDropdown.classList.contains('shown')) {
      document.querySelector('.header-spree').classList.remove('above-overlay')
      document.getElementById('overlay').classList.remove('shown')
      searchDropdown.classList.remove('shown')
    } else {
      document.querySelector('.header-spree').classList.add('above-overlay')
      document.getElementById('overlay').classList.add('shown')
      searchDropdown.classList.add('shown')
      document.querySelector('#search-dropdown input').focus()
    }
  }
})
