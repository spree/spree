var getQueryString = window.location.search
var urlParams = new URLSearchParams(getQueryString)
var variantIdFromUrl = urlParams.get('variant')

this.initializeQueryParamsCheck = function () {
  if (urlParams.has('variant')) verifyVariantIdMatch()
}

function verifyVariantIdMatch() {
  this.variants.forEach(function(variant) {
    if (parseInt(variant.id) === parseInt(variantIdFromUrl)) this.urlQueryMatchFound = true
  })
}

this.setSelectedVariantFromUrl = function () {
  this.selectedOptions = []

  this.getVariantOptionsById(variantIdFromUrl)
  this.sortArrayByOptionTypeIndex(this.selectedOptions)
  this.clickListOptions(this.selectedOptions)
  this.updateStructuredData()
}

this.getVariantOptionsById = function(variantIdFromUrl) {
  this.variants.forEach(function(variant) {
    if (parseInt(variant.id) === parseInt(variantIdFromUrl)) this.sortOptionValues(variant.option_values)
  })
}

this.sortOptionValues = function(optVals) {
  optVals.forEach(buildArray)
}

function buildArray(item) {
  var container = document.querySelector('ul#product-variants')
  var target = container.querySelectorAll('.product-variants-variant-values-radio')

  target.forEach(function(inputTag) {
    if (parseInt(inputTag.value) === item.id && inputTag.dataset.presentation === item.presentation) {
      this.selectedOptions.push(inputTag)
    }
  })
}

this.sortArrayByOptionTypeIndex = function (arrayOfOptions) {
  arrayOfOptions.sort(function (a, b) {
    return a.dataset.optionTypeIndex > b.dataset.optionTypeIndex ? 1 : -1;
  })
}

this.clickListOptions = function(list) {
  list.forEach(function (item) {
    item.checked = true
    var $optionListItem = $(item)
    this.applyCheckedOptionValue($optionListItem)
  })
}

this.updateStructuredData = function() {
  var variant = this.selectedVariant()
  var host = window.location.host
  var schemaData = document.body.querySelector("script[type='application/ld+json']")
  var obj = JSON.parse(schemaData.firstChild.nodeValue)
  var firstLayer = obj[0]
  var offers = obj[0].offers

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
  offers.price = variant.price.amount

  if (Array.isArray(variant.images) && (variant.images.length)) {
    firstLayer.image = host + variant.images[0].url_product
  }

  schemaData.firstChild.nodeValue = JSON.stringify(obj)
}

this.initializeColorVarianTooltip = function() {
  var colorVariants = $('.color-select-label[data-toggle="tooltip"]')
  colorVariants.tooltip({
    placement: 'bottom'
  })
}
