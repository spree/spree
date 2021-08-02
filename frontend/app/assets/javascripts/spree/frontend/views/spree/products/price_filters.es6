Spree.ready(function() {
  class PriceRangeFilter {
    constructor(inputsContainer, filterButton) {
      this.inputsContainer = inputsContainer
      this.filterButton = filterButton

      this.priceInputs = inputsContainer.querySelectorAll('input')
      this.minPriceInput = inputsContainer.querySelector('input[name="min_price"]')
      this.maxPriceInput = inputsContainer.querySelector('input[name="max_price"]')
    }

    handlePriceChange() {
      this.priceInputs.forEach((priceInput) => {
        priceInput.addEventListener('change', () => {
          this.updatePricesForFiltering(
            parseInt(this.minPriceInput.value) || 0,
            parseInt(this.maxPriceInput.value) || 'Infinity'
          )
        })
      })
    }

    updatePricesForFiltering(minPrice, maxPrice) {
      const formattedPriceRange = `${minPrice}-${maxPrice}`
      const url = new URL(this.filterButton.href)

      url.searchParams.set('price', formattedPriceRange)
      this.filterButton.href = `${url.pathname}${url.search}`
    }
  }

  // we have 2 elements for filtering prices - desktop and mobile
  const desktopElement = document.getElementById('filterPriceRangeDesktop')
  if (desktopElement) {
    const desktopFilterButton = desktopElement.querySelector('a')
    const desktopPriceRangeFilter = new PriceRangeFilter(desktopElement, desktopFilterButton)
    desktopPriceRangeFilter.handlePriceChange()
  }

  const mobileElement = document.getElementById('filterPriceRangeMobile')
  if (mobileElement) {
    const mobileFilterButton = document.getElementById('filterProductsButtonMobile')
    const mobilePriceRangeFilter = new PriceRangeFilter(mobileElement, mobileFilterButton)
    mobilePriceRangeFilter.handlePriceChange()
  }
});
