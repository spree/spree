//= require spree/api/storefront/cart
//= require ../shared/product_added_modal
//= require ../shared/variant_select

var ADD_TO_CART_FORM_SELECTOR = '.add-to-cart-form'
var VARIANT_ID_SELECTOR = '[name="variant_id"]'
var OPTION_VALUE_SELECTOR = '.product-variants-variant-values-radio'
var ADD_TO_CART_SELECTOR = '.add-to-cart-button'

var AVAILABILITY_TEMPLATES = {
  notAvailableInCurrency: '.availability-template-not-available-in-currency',
  inStock: '.availability-template-in-stock',
  backorderable: '.availability-template-backorderable',
  outOfStock: '.availability-template-out-of-stock'
}

function CartForm($, $cartForm) {
  this.constructor = function() {
    this.initialize()
    this.bindEventHandlers()
  }

  this.initialize = function() {
    this.urlQueryMatchFound = false
    this.selectedOptionValueIds = []
    this.variants = JSON.parse($cartForm.attr('data-variants'))
    this.withOptionValues = Boolean($cartForm.find(OPTION_VALUE_SELECTOR).length)

    this.$addToCart = $cartForm.find(ADD_TO_CART_SELECTOR)
    this.$price = $cartForm.find('.price.selling')
    this.$compareAtPrice = $cartForm.find('.compare-at-price')
    this.$variantIdInput = $cartForm.find(VARIANT_ID_SELECTOR)

    this.initializeQueryParamsCheck()
    this.initializeColorVarianTooltip()

    if (this.urlQueryMatchFound) {
      this.setSelectedVariantFromUrl()
    } else {
      this.initializeForm()
    }
  }

  this.initializeForm = function() {
    if (this.withOptionValues) {
      var $optionValue = this.firstCheckedOptionValue()
      this.applyCheckedOptionValue($optionValue, true)
      var singleOptionValues = this.getSingleOptionValuesFromEachOptionType()
      if (singleOptionValues.length) {
        singleOptionValues.forEach(function($value) {
          this.applyCheckedOptionValue($value, true)
        })
      }
    } else {
      this.updateAddToCart()
      this.triggerVariantImages()
    }
  }

  this.bindEventHandlers = function() {
    $cartForm.on('click', OPTION_VALUE_SELECTOR, this.handleOptionValueClick)
  }

  this.handleOptionValueClick = function(event) {
    var currentTarget = $(event.currentTarget)
    this.applyCheckedOptionValue(currentTarget)
    currentTarget.blur()
  }.bind(this)

  this.applyCheckedOptionValue = function($optionValue, initialUpdate) {
    this.saveCheckedOptionValue($optionValue)
    this.showAvailableVariants()
    this.updateAddToCart()
    // we don't want to remove availability status on initial page load
    if (!initialUpdate) this.updateVariantAvailability()
    this.updateVariantPrice()
    this.updateVariantId()

    if (this.shouldTriggerVariantImage($optionValue)) {
      this.triggerVariantImages()
    }

    if (initialUpdate) $optionValue.prop('checked', true)
  }

  this.saveCheckedOptionValue = function($optionValue) {
    var optionTypeIndex = $optionValue.data('option-type-index')

    this.selectedOptionValueIds.splice(
      optionTypeIndex,
      this.selectedOptionValueIds.length,
      parseInt($optionValue.val())
    )
  }

  this.showAvailableVariants = function() {
    var availableOptionValueIds = this.availableOptionValueIds()
    var selectedOptionValueIdsCount = this.selectedOptionValueIds.length

    this.optionTypes().each(function(index, optionType) {
      if (index < selectedOptionValueIdsCount) return

      $(optionType)
        .find(OPTION_VALUE_SELECTOR)
        .each(function(_index, ov) {
          var $ov = $(ov)
          var id = parseInt($ov.val())

          $ov.prop('checked', false)
          $ov.prop('disabled', !availableOptionValueIds.includes(id))
        })
    })
  }

  this.optionTypes = function() {
    return $cartForm.find('.product-variants-variant')
  }

  this.availableOptionValueIds = function() {
    var selectedOptionValueIds = this.selectedOptionValueIds

    return this.variants.reduce(function(acc, variant) {
      var optionValues = variant.option_values.map(function(ov) {
        return ov.id
      })

      var isPossibleVariantFound = selectedOptionValueIds.every(function(ov) {
        return optionValues.includes(ov)
      })

      if (isPossibleVariantFound) {
        return acc.concat(optionValues)
      }

      return acc
    }, [])
  }

  this.firstCheckedOptionValue = function() {
    return $cartForm.find(OPTION_VALUE_SELECTOR + '[data-option-type-index=0]' + ':checked')
  }

  this.getSingleOptionValuesFromEachOptionType = function() {
    var singleOptionValues = []
    this.optionTypes().each(function(_, optionType) {
      var $optionValues = $(optionType).find(OPTION_VALUE_SELECTOR)
      if ($optionValues.length === 1) {
        singleOptionValues.push($optionValues.first())
      }
    })
    return singleOptionValues
  }

  this.shouldTriggerVariantImage = function($optionValue) {
    return $optionValue.data('is-color') || !this.firstCheckedOptionValue().data('is-color')
  }

  this.triggerVariantImages = function() {
    var checkedVariantId
    var variant = this.selectedVariant()

    if (variant) {
      checkedVariantId = variant.id
    } else {
      checkedVariantId = this.firstCheckedOptionValue().data('variant-id')
    }

    // Wait for listeners to attach.
    setTimeout(function() {
      $cartForm.trigger({
        type: 'variant_id_change',
        triggerId: $cartForm.attr('data-variant-change-trigger-identifier'),
        variantId: checkedVariantId + ''
      })
    })
  }

  this.selectedVariant = function() {
    var self = this

    if (!this.withOptionValues) {
      return this.variants.find(function(variant) {
        return variant.id === parseInt(self.$variantIdInput.val())
      })
    }

    if (this.variants.length === 1 && this.variants[0].is_master) {
      return this.variants[0]
    }

    return this.variants.find(function(variant) {
      var optionValueIds = variant.option_values.map(function(ov) {
        return ov.id
      })

      return self.areArraysEqual(optionValueIds, self.selectedOptionValueIds)
    })
  }

  this.areArraysEqual = function(array1, array2) {
    return this.sortArray(array1).join(',') === this.sortArray(array2).join(',')
  }

  this.sortArray = function(array) {
    return array.concat().sort(function(a, b) {
      if (a < b) return -1
      if (a > b) return 1

      return 0
    })
  }

  this.updateAddToCart = function() {
    var variant = this.selectedVariant()

    this.$addToCart.prop('disabled', variant ? !variant.purchasable : true)
  }

  this.availabilityMessage = function(variant) {
    if (!variant.is_product_available_in_currency) {
      return $(AVAILABILITY_TEMPLATES.notAvailableInCurrency).html()
    }

    if (variant.in_stock) {
      return $(AVAILABILITY_TEMPLATES.inStock).html()
    }

    if (variant.backorderable) {
      return $(AVAILABILITY_TEMPLATES.backorderable).html()
    }

    return $(AVAILABILITY_TEMPLATES.outOfStock).html()
  }

  this.updateVariantAvailability = function() {
    var variant = this.selectedVariant()

    if (!variant) {
      return $cartForm
        .find('.add-to-cart-form-general-availability .add-to-cart-form-general-availability-value')
        .html('')
    }

    return $cartForm
      .find('.add-to-cart-form-general-availability .add-to-cart-form-general-availability-value')
      .html(this.availabilityMessage(variant))
  }

  this.updateVariantPrice = function() {
    var variant = this.selectedVariant()

    if (!variant) return

    var shouldDisplayCompareAtPrice = variant.should_display_compare_at_price

    this.$price.html(variant.display_price)

    var compareAtPriceContent = shouldDisplayCompareAtPrice ? variant.display_compare_at_price : ''
    this.$compareAtPrice.html(compareAtPriceContent)
  }

  this.updateVariantId = function() {
    var variant = this.selectedVariant()
    var variantId = (variant && variant.id) || ''

    this.$variantIdInput.val(variantId)
  }

  this.constructor()
}

Spree.ready(function($) {
  Spree.variantById = function($cartForm, variantId) {
    var cartFormVariants = JSON.parse($cartForm.attr('data-variants'))
    return (
      cartFormVariants.find(function(variant) {
        return variant.id.toString() === variantId
      }) || null
    )
  }

  Spree.addToCartFormSubmissionOptions = function() {
    return {};
  }

  $('#product-details').on('submit', ADD_TO_CART_FORM_SELECTOR, function(event) {
    var $cartForm = $(event.currentTarget);
    var $addToCart = $cartForm.find(ADD_TO_CART_SELECTOR);
    var variantId = $cartForm.find(VARIANT_ID_SELECTOR).val();
    var quantity = parseInt($cartForm.find('[name="quantity"]').val());
    var options = Spree.addToCartFormSubmissionOptions();

    event.preventDefault()
    $addToCart.prop('disabled', true);
    Spree.ensureCart(function() {
      SpreeAPI.Storefront.addToCart(
        variantId,
        quantity,
        options, // options hash - you can pass additional parameters here, your backend
        // needs to be aware of those, see API docs:
        // https://github.com/spree/spree/blob/master/api/docs/v2/storefront/index.yaml#L42
        function(response) {
          $addToCart.prop('disabled', false)
          Spree.fetchCart()
          Spree.showProductAddedModal(JSON.parse(
            $cartForm.attr('data-product-summary')
          ), Spree.variantById($cartForm, variantId))
          $cartForm.trigger({
            type: 'product_add_to_cart',
            variant: Spree.variantById($cartForm, variantId),
            quantity_increment: quantity,
            cart: response.attributes
          })
        },
        function(error) {
          if (typeof error === 'string' && error !== '') {
            document.querySelector('#no-product-available .no-product-available-text').innerText = error
          }
          document.getElementById('overlay').classList.add('shown')
          document.getElementById('no-product-available').classList.add('shown')
          window.scrollTo(0, 0)
          $addToCart.prop('disabled', false)
        } // failure callback for 422 and 50x errors
      )
    })
  })

  $(ADD_TO_CART_FORM_SELECTOR).each(function(_cartFormIndex, cartFormElement) {
    var $cartForm = $(cartFormElement)

    CartForm($, $cartForm)
  })

  document.addEventListener('turbolinks:request-start', function () {
    Spree.hideProductAddedModal()
  })
})
