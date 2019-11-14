Spree.ready(function() {
  var searchIcons = document.querySelectorAll('#nav-bar .search-icons')[0]

  if (searchIcons !== undefined) {
    searchIcons.addEventListener(
      'click',
      function() {
        document.querySelector('.header-spree').classList.add('above-overlay')
        document.getElementById('overlay').classList.add('shown')
        document.getElementById('search-dropdown').classList.add('shown')
        document.querySelector('#search-dropdown input').focus()
      },
      false
    )
  }
})
