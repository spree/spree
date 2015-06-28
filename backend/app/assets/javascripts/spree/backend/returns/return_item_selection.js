$(document).ready(function() {
  var formFields = $("[data-hook='admin_customer_return_form_fields'], \
                     [data-hook='admin_return_authorization_form_fields']");

  if(formFields.length > 0) {
    function checkAddItemBox() {
      $(this).closest('tr').find('input.add-item').attr('checked', 'checked');
      updateSuggestedAmount();
    }

    function updateSuggestedAmount() {
      var totalPretaxRefund = 0;
      var checkedItems = formFields.find('input.add-item:checked');
      $.each(checkedItems, function(i, checkbox) {
        var id = $(checkbox).data("id");
        totalPretaxRefund += parseFloat($(".js-refund-amount-input-" + id).val());
      });

      var displayTotal = isNaN(totalPretaxRefund) ? '' : totalPretaxRefund.toFixed(2);
      formFields.find('span#total_pre_tax_refund').html(displayTotal);
    }

    updateSuggestedAmount();

    formFields.find('input#select-all').on('change', function(ev) {
      var checkBoxes = $(ev.currentTarget).parents('form:first').find('input.add-item');
      checkBoxes.prop('checked', this.checked);
      updateSuggestedAmount();
    });

    formFields.find('input.add-item').on('change', updateSuggestedAmount);
    formFields.find('.refund-amount-input').on('keyup', updateSuggestedAmount);

    formFields.find('input, select').not('.add-item').on('change', checkAddItemBox);
  }
});
