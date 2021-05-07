Spree.ready(function() {
  const priceRangeFilterElement = document.getElementById('filterPriceRange')
  const priceInputs = priceRangeFilterElement.querySelectorAll('input')
  const minPriceInput = priceRangeFilterElement.querySelector('input[name="min_price"]')
  const maxPriceInput = priceRangeFilterElement.querySelector('input[name="max_price"]')

  priceInputs.forEach((priceInput) => {
    priceInput.addEventListener('change', () => {
      updatePriceRangeFilter(
        parseInt(minPriceInput.value) || 0,
        parseInt(maxPriceInput.value) || 0
      )
    })
  })

  function updatePriceRangeFilter(minPrice, maxPrice) {
    const formattedPriceRange = `${minPrice} - ${maxPrice}`

    const priceRangeSubmitButton = priceRangeFilterElement.querySelector('a')
    const dataParams = JSON.parse(priceRangeSubmitButton.dataset.params)
    const urlParams = new URLSearchParams(dataParams)

    urlParams.set('price', formattedPriceRange)
    priceRangeSubmitButton.href = decodeURIComponent(`${location.pathname}?${urlParams.toString()}`)
  }
});
