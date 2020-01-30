//= require spree/api/storefront/cart
//= require ../shared/product_added_modal

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
    this.selectedOptionValueIds = []
    this.variants = JSON.parse($cartForm.attr('data-variants'))
    this.withOptionValues = Boolean($cartForm.find(OPTION_VALUE_SELECTOR).length)

    this.$addToCart = $cartForm.find(ADD_TO_CART_SELECTOR)
    this.$price = $cartForm.find('.price.selling')
    this.$variantIdInput = $cartForm.find(VARIANT_ID_SELECTOR)

    this.initializeForm()
  }

  this.initializeForm = function() {
    if (this.withOptionValues) {
      var $optionValue = this.firstCheckedOptionValue()
      this.applyCheckedOptionValue($optionValue)
    } else {
      this.updateAddToCart()
      this.triggerVariantImages()
    }
  }

  this.bindEventHandlers = function() {
    $cartForm.on('click', OPTION_VALUE_SELECTOR, this.handleOptionValueClick)
  }

  this.handleOptionValueClick = function(event) {
    this.applyCheckedOptionValue($(event.currentTarget))
  }.bind(this)

  this.applyCheckedOptionValue = function($optionValue) {
    this.saveCheckedOptionValue($optionValue)
    this.showAvailableVariants()
    this.updateAddToCart()
    this.updateVariantAvailability()
    this.updateVariantPrice()
    this.updateVariantId()

    if (this.shouldTriggerVariantImage($optionValue)) {
      this.triggerVariantImages()
    }
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

  this.shouldTriggerVariantImage = function($optionValue) {
    return $optionValue.data('is-color') || !this.firstCheckedOptionValue().data('is-color')
  }

  this.triggerVariantImages = function() {
    var checkedVariantId
    var variant = this.selectedVariant()
    var $carousel = $('#productThumbnailsCarousel')
    ThumbnailsCarousel($, $carousel)

    if (variant) {
      checkedVariantId = variant.id
    } else {
      checkedVariantId = this.firstCheckedOptionValue().data('variant-id')
    }

    var imagesCount = this.checkImagesCount(checkedVariantId, $carousel)
    this.showOrHideVariantImages(imagesCount, $carousel)

    // Wait for listeners to attach.
    setTimeout(function() {
      $cartForm.trigger({
        type: 'variant_id_change',
        triggerId: $cartForm.attr('data-variant-change-trigger-identifier'),
        variantId: checkedVariantId + ''
      })
    })
  }

  this.checkImagesCount = function(variantId, carousel) {
    var images = []

    carousel
      .find('[data-variant-id]')
      .each(function(_itemIndex, slideElement) {
        var $slide = $(slideElement)
        var qualifies = $slide.attr('data-variant-id') === `${variantId}`

        if (qualifies === true) {
          images.push(slideElement)
        }
      })

    return images.length
  }

  this.showOrHideVariantImages = function(imagesCount, carousel) {
    if (imagesCount <= 1) {
      document.getElementById('desktop-thumbnails').classList.remove('d-md-block')
      document.getElementById('mobile-thumbnails').classList.remove('d-sm-block')
      document.getElementById('mobile-single-list').classList.add('d-none')
      $('.product-carousel-control--previous').each(function(i, e) {
        e.classList.remove('d-md-flex')
      });
      $('.product-carousel-control--next').each(function(i, e) {
        e.classList.remove('d-md-flex')
      });
    } else {
      document.getElementById('desktop-thumbnails').classList.add('d-md-block')
      document.getElementById('mobile-thumbnails').classList.add('d-sm-block')
      document.getElementById('mobile-single-list').classList.remove('d-none')
      $('.product-carousel-control--previous').each(function(i, e) {
        e.classList.add('d-md-flex')
      });
      $('.product-carousel-control--next').each(function(i, e) {
        e.classList.add('d-md-flex')
      });
    }
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

    if (!variant) return

    return $cartForm
      .find('.add-to-cart-form-general-availability .add-to-cart-form-general-availability-value')
      .html(this.availabilityMessage(variant))
  }

  this.updateVariantPrice = function() {
    var variant = this.selectedVariant()

    if (!variant) return

    this.$price.text(variant.display_price)
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

  $('#product-details').on('submit', ADD_TO_CART_FORM_SELECTOR, function(event) {
    var variantId
    var quantity
    var $cartForm = $(event.currentTarget)
    var $addToCart = $cartForm.find(ADD_TO_CART_SELECTOR)

    event.preventDefault()
    $addToCart.prop('disabled', true)
    variantId = $cartForm.find(VARIANT_ID_SELECTOR).val()
    quantity = parseInt($cartForm.find('[name="quantity"]').val())
    Spree.ensureCart(function() {
      SpreeAPI.Storefront.addToCart(
        variantId,
        quantity,
        {}, // options hash - you can pass additional parameters here, your backend
        // needs to be aware of those, see API docs:
        // https://github.com/spree/spree/blob/master/api/docs/v2/storefront/index.yaml#L42
        function(response) {
          $addToCart.prop('disabled', false)
          Spree.fetchCart()
          Spree.showProductAddedModal(JSON.parse(
            $cartForm.attr('data-product-summary')
          ), Spree.variantById($cartForm, variantId))
        },
        function(_error) {
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
})
