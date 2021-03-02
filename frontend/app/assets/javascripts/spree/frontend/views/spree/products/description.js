document.addEventListener('turbolinks:load', function () {
  $('#product-description-arrow').click(function () {
    document.getElementById('product-description-long').classList.remove('d-none')
    document.getElementById('product-description-short').classList.add('d-none')
    document.getElementById('product-description-arrow').classList.remove('d-flex')
    document.getElementById('product-description-arrow').classList.add('d-none')
  })
})
