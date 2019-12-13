Spree.ready(function($) {
  var deleteAddressLinks = document.querySelectorAll('.js-delete-address-link');
  if (deleteAddressLinks.length > 0) {
    deleteAddressLinks.forEach(function(deleteLink) {
      deleteLink.addEventListener('click', function(e) {
        document.querySelector('#overlay').classList.add('shown');
        document.querySelector('#delete-address-popup').classList.add('shown');
        document.querySelector('#delete-address-popup-confirm').href = e.currentTarget.dataset.address;
      }, false)
    })
  }

  document.querySelector('#overlay').addEventListener('click', function () {
    var addressActionElement = document.querySelector('#delete-address-popup');
    if (addressActionElement) addressActionElement.classList.remove('shown');
  }, false);

  var popupCloseButtons = document.querySelectorAll('.js-delete-address-popup-close-button')
  if (popupCloseButtons.length > 0) {
    popupCloseButtons.forEach(function(closeButton) {
      closeButton.addEventListener('click', function(e) {
        document.querySelector('#overlay').classList.remove('shown');
        document.querySelector('#delete-address-popup').classList.remove('shown');
      })
    })
  }
})
