var initProductActions = function () {
  /* globals Handlebars */
  'use strict';

  // Add classes on promotion items for design
  $(document).on('mouseover mouseout', 'a.delete', function (event) {
    if (event.type === 'mouseover') {
      $(this).parent().addClass('action-remove');
    } else {
      $(this).parent().removeClass('action-remove');
    }
  });

  $('#promotion-filters').find('.variant_autocomplete').variantAutocomplete();

  $('.calculator-fields').each(function () {
    var $fields_container = $(this);
    var $type_select = $fields_container.find('.type-select');
    var $settings = $fields_container.find('.settings');
    var $warning = $fields_container.find('.js-warning');
    var originalType = $type_select.val();

    $warning.hide();
    $type_select.change(function () {
      if ($(this).val() === originalType) {
        $warning.hide();
        $settings.show();
        $settings.find('input').removeProp('disabled');
      } else {
        $warning.show();
        $settings.hide();
        $settings.find('input').prop('disabled', 'disabled');
      }
    });
  });

  //
  // Option Value Promo Rule
  //
  if ($('#promo-rule-option-value-template').length) {
    var optionValueSelectNameTemplate = Handlebars.compile($('#promo-rule-option-value-option-values-select-name-template').html());
    var optionValueTemplate = Handlebars.compile($('#promo-rule-option-value-template').html());

    var addOptionValue = function(product, values) {
      $('.js-promo-rule-option-values').append(optionValueTemplate({
        productSelect: {value: product},
        optionValuesSelect: {value: values}
      }));
      var optionValue = $('.js-promo-rule-option-values .promo-rule-option-value').last();
      optionValue.find('.js-promo-rule-option-value-product-select').productAutocomplete({multiple: false});
      optionValue.find('.js-promo-rule-option-value-option-values-select').optionValueAutocomplete({
        productSelect: '.js-promo-rule-option-value-product-select'
      });
      if (product === null) {
        optionValue.find('.js-promo-rule-option-value-option-values-select').prop('disabled', true);
      }
    };

    var originalOptionValues = $('.js-original-promo-rule-option-values').data('original-option-values');
    if (!$('.js-original-promo-rule-option-values').data('loaded')) {
      if ($.isEmptyObject(originalOptionValues)) {
        addOptionValue(null, null);
      } else {
        $.each(originalOptionValues, addOptionValue);
      }
    }
    $('.js-original-promo-rule-option-values').data('loaded', true);

    $(document).on('click', '.js-add-promo-rule-option-value', function (event) {
      event.preventDefault();
      addOptionValue(null, null);
    });

    $(document).on('click', '.js-remove-promo-rule-option-value', function () {
      $(this).parents('.promo-rule-option-value').remove();
    });

    $(document).on('change', '.js-promo-rule-option-value-product-select', function () {
      var optionValueSelect = $(this).parents('.promo-rule-option-value').find('.js-promo-rule-option-value-option-values-select');
      optionValueSelect.attr('name', optionValueSelectNameTemplate({productId: $(this).val()}).trim());
      optionValueSelect.prop('disabled', $(this).val() === '').select2('val', '');
    });
  }

  //
  // Tiered Calculator
  //
  if ($('#tier-fields-template').length && $('#tier-input-name').length) {
    var tierFieldsTemplate = Handlebars.compile($('#tier-fields-template').html());
    var tierInputNameTemplate = Handlebars.compile($('#tier-input-name').html());

    var originalTiers = $('.js-original-tiers').data('original-tiers');
    $.each(originalTiers, function(base, value) {
      var fieldName = tierInputNameTemplate({base: base}).trim();
      $('.js-tiers').append(tierFieldsTemplate({
        baseField: {value: base},
        valueField: {name: fieldName, value: value}
      }));
    });

    $(document).on('click', '.js-add-tier', function(event) {
      event.preventDefault();
      $('.js-tiers').append(tierFieldsTemplate({valueField: {name: null}}));
    });

    $(document).on('click', '.js-remove-tier', function(event) {
      $(this).parents('.tier').remove();
    });

    $(document).on('change', '.js-base-input', function(event) {
      var valueInput = $(this).parents('.tier').find('.js-value-input');
      valueInput.attr('name', tierInputNameTemplate({base: $(this).val()}).trim());
    });
  }

  //
  // CreateLineItems Promotion Action
  //
  (function () {
    var hideOrShowItemTables = function () {
      $('.promotion_action table').each(function () {
        if ($(this).find('td').length === 0) {
          $(this).hide();
        } else {
          $(this).show();
        }
      });
    };
    hideOrShowItemTables();

    // Remove line item
    var setupRemoveLineItems = function () {
      $('.remove_promotion_line_item').on('click', function () {
        var line_items_el = $($('.line_items_string')[0]);
        var finder = new RegExp($(this).data('variant-id') + "x\\d+");
        line_items_el.val(line_items_el.val().replace(finder, ''));
        $(this).parents('tr').remove();
        hideOrShowItemTables();
      });
    };

    setupRemoveLineItems();
    // Add line item to list
    $('.promotion_action.create_line_items button.add').unbind('click').click(function () {
      var $container = $(this).parents('.promotion_action');
      var product_name = $container.find('input[name="add_product_name"]').val();
      var variant_id = $container.find('input[name="add_variant_id"]').val();
      var quantity = $container.find('input[name="add_quantity"]').val();
      if (variant_id) {
        // Add to the table
        var newRow = '<tr><td>' + product_name + '</td><td>' + quantity + '</td><td><img src="/assets/admin/icons/cross.png"/></td></tr>';
        $container.find('table').append(newRow);
        // Add to serialized string in hidden text field
        var $hiddenField = $container.find('.line_items_string');
        $hiddenField.val($hiddenField.val() + ',' + variant_id + 'x' + quantity);
        setupRemoveLineItems();
        hideOrShowItemTables();
      }
      return false;
    });

  })();

};

$(document).ready(function () {

  initProductActions();

});
