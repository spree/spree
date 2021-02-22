function initProductActions () {
  'use strict'

  $('#promotion-filters').find('.variant_autocomplete').variantAutocomplete()

  $('.calculator-fields').each(function () {
    var $fieldsContainer = $(this)
    var $typeSelect = $fieldsContainer.find('.type-select')
    var $settings = $fieldsContainer.find('.settings')
    var $warning = $fieldsContainer.find('.js-warning')
    var originalType = $typeSelect.val()

    $warning.hide()
    $typeSelect.change(function () {
      if ($(this).val() === originalType) {
        $warning.hide()
        $settings.show()
        $settings.find('input').removeProp('disabled')
      } else {
        $warning.show()
        $settings.hide()
        $settings.find('input').prop('disabled', 'disabled')
      }
    })
  })

  //
  // Option Value Promo Rule
  //
  if ($('#promo-rule-option-value-template').length) {
    var optionValueSelectNameTemplate = Handlebars.compile($('#promo-rule-option-value-option-values-select-name-template').html())
    var optionValueTemplate = Handlebars.compile($('#promo-rule-option-value-template').html())
    var optionValuesList = $('.js-promo-rule-option-values')

    var addOptionValue = function (productId, values) {
      var template = optionValueTemplate({
        productId: productId
      })

      optionValuesList.append(template)

      var optionValueId = '#promo-rule-option-value-'
      if (productId) {
        optionValueId += productId.toString()
      }
      var optionValue = optionValuesList.find(optionValueId)

      var productSelect = optionValue.find('.js-promo-rule-option-value-product-select')
      var valuesSelect = optionValue.find('.js-promo-rule-option-value-option-values-select')

      productSelect.productAutocomplete({ multiple: false, values: productId })
      productSelect.on('select2:select', function(e) {
        valuesSelect.attr('disabled', false).removeClass('d-none').addClass('d-block')
        valuesSelect.attr('name', optionValueSelectNameTemplate({ productId: productSelect.val() }).trim())
        valuesSelect.optionValueAutocomplete({
          productId: productId,
          productSelect: productSelect,
          multiple: true,
          values: values,
          clearSelection: productId != productSelect.val()
        })
      })
    }

    var originalOptionValues = $('.js-original-promo-rule-option-values').data('original-option-values')
    if (!$('.js-original-promo-rule-option-values').data('loaded')) {
      if ($.isEmptyObject(originalOptionValues)) {
        addOptionValue(null, null)
      } else {
        $.each(originalOptionValues, addOptionValue)
      }
    }
    $('.js-original-promo-rule-option-values').data('loaded', true)

    $(document).on('click', '.js-add-promo-rule-option-value', function (event) {
      event.preventDefault()
      addOptionValue(null, null)
    })

    $(document).on('click', '.js-remove-promo-rule-option-value', function () {
      $(this).parents('.promo-rule-option-value').remove()
    })
  }

  //
  // Tiered Calculator
  //
  if ($('#tier-fields-template').length && $('#tier-input-name').length) {
    var tierFieldsTemplate = Handlebars.compile($('#tier-fields-template').html())
    var tierInputNameTemplate = Handlebars.compile($('#tier-input-name').html())

    var originalTiers = $('.js-original-tiers').data('original-tiers')
    $.each(originalTiers, function (base, value) {
      var fieldName = tierInputNameTemplate({ base: base }).trim()
      $('.js-tiers').append(tierFieldsTemplate({
        baseField: { value: base },
        valueField: { name: fieldName, value: value }
      }))
    })

    $(document).on('click', '.js-add-tier', function (event) {
      event.preventDefault()
      $('.js-tiers').append(tierFieldsTemplate({ valueField: { name: null } }))
    })

    $(document).on('click', '.js-remove-tier', function (event) {
      $(this).parents('.tier').remove()
    })

    $(document).on('change', '.js-base-input', function (event) {
      var valueInput = $(this).parents('.tier').find('.js-value-input')
      valueInput.attr('name', tierInputNameTemplate({ base: $(this).val() }).trim())
    })
  }

  //
  // CreateLineItems Promotion Action
  //
  (function () {
    function hideOrShowItemTables () {
      $('.promotion_action table').each(function () {
        if ($(this).find('td').length === 0) {
          $(this).hide()
        } else {
          $(this).show()
        }
      })
    }
    hideOrShowItemTables()

    // Remove line item
    function setupRemoveLineItems () {
      $('.remove_promotion_line_item').on('click', function () {
        var lineItemsEl = $($('.line_items_string')[0])
        var finder = new RegExp($(this).data('variant-id') + 'x\\d+')
        lineItemsEl.val(lineItemsEl.val().replace(finder, ''))
        $(this).parents('tr').remove()
        hideOrShowItemTables()
      })
    }

    setupRemoveLineItems()
    // Add line item to list
    $('.promotion_action.create_line_items button.add').off('click').click(function () {
      var $container = $(this).parents('.promotion_action')
      var product_name = $container.find('input[name="add_product_name"]').val()
      var variant_id = $container.find('input[name="add_variant_id"]').val()
      var quantity = $container.find('input[name="add_quantity"]').val()
      if (variant_id) {
        // Add to the table
        var newRow = '<tr><td>' + product_name + '</td><td>' + quantity + '</td><td><i class="icon icon-cancel"></i></td></tr>'
        $container.find('table').append(newRow)
        // Add to serialized string in hidden text field
        var $hiddenField = $container.find('.line_items_string')
        $hiddenField.val($hiddenField.val() + ',' + variantId + 'x' + quantity)
        setupRemoveLineItems()
        hideOrShowItemTables()
      }
      return false
    })
  })()
}

$(document).ready(function () {
  var promotion_form = $('form.edit_promotion')

  if (promotion_form.length) {
    initProductActions()
  }
})
