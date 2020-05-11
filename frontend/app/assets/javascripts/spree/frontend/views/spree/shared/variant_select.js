/* global queryMatchFound */

let getQueryString = window.location.search
let urlParams = new URLSearchParams(getQueryString)
let variantIdFromUrl = urlParams.get('variant')
let queryMatchFound = false

this.initializeQueryParamsCheck = function () {
  if (urlParams.has('variant')) {
    this.variants.forEach(varifyVariantID)
  }
}

function varifyVariantID() {
  for (const variant of this.variants) {
    if (parseInt(variant.id) === parseInt(variantIdFromUrl)) {
      queryMatchFound = true
    }
  }
}

this.setSelectedVariantFromUrl = function () {
  this.selectedOptions = []
  this.getVariantOptionsById(variantIdFromUrl)
  this.selectedOptions.sort((a, b) => (a.dataset.optionTypeIndex > b.dataset.optionTypeIndex) ? 1 : -1)
  this.clickListOptions(this.selectedOptions)
  this.updateStructuredData()
}

this.getVariantOptionsById = function(variantIdFromUrl) {
  for (const v of this.variants) {
    if (parseInt(v.id) === parseInt(variantIdFromUrl)) {
      this.sortOptionValues(v.option_values)
    }
  }
}

this.sortOptionValues = function(optVals) {
  optVals.forEach(buidArray)
}

function buidArray(item) {
  const container = document.querySelector('ul#product-variants')
  const target = container.querySelectorAll('.product-variants-variant-values-radio')

  for (const inputTag of target) {
    if (parseInt(inputTag.value) === item.id && inputTag.dataset.presentation === item.presentation) {
      this.selectedOptions.push(inputTag)
    }
  }
}

this.clickListOptions = function(list) {
  list.forEach(selectOpts)

  function selectOpts(item, index) {
    item.click()
    var $t = $(item)
    this.applyCheckedOptionValue($t)
  }
}

this.updateStructuredData = function() {
  const variant = this.selectedVariant()
  const host = window.location.host
  const script = document.getElementById('productStructuredData')
  const obj = JSON.parse(script.firstChild.nodeValue)
  const firstLayer = obj[0]
  const offers = obj[0].offers

  if (variant.purchasable) {
    offers.availability = 'InStock'
  } else {
    offers.availability = 'OutOfStock'
  }

  if (variant.sku.length > 1) {
    firstLayer.sku = variant.sku
  }

  firstLayer.url = window.location.href
  offers.url = window.location.href
  offers.price = variant.display_price

  if (Array.isArray(variant.images) && (variant.images.length)) {
    firstLayer.image = host + variant.images[0].url_product
  }

  script.firstChild.nodeValue = JSON.stringify(obj)
}
