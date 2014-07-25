$(document).ready(function() {
  var formFields = $("[data-hook='admin_customer_return_form_fields'], \
                     [data-hook='admin_return_authorization_form_fields']");

  if(formFields.length > 0) {
    function updateSuggestedAmount() {
      var totalPretaxRefund = 0;
      var checkedItems = formFields.find('input.add-item:checked');
      $.each(checkedItems, function(i, checkbox) {
        totalPretaxRefund += parseFloat($(checkbox).parents('tr').find('.refund-amount-input').val());
      });

      var displayTotal = isNaN(totalPretaxRefund) ? '' : totalPretaxRefund.toFixed(2);
      formFields.find('span#total_pre_tax_refund').html(displayTotal);
    }

    updateSuggestedAmount();

    formFields.find('input#select-all').on('change', function(ev) {
      var checkBoxes = $(ev.currentTarget).parents('table:first').find('input.add-item');
      checkBoxes.prop('checked', this.checked);
      updateSuggestedAmount();
    });

    formFields.find('input.add-item').on('change', updateSuggestedAmount);
    formFields.find('.refund-amount-input').on('keyup', updateSuggestedAmount);
  }
});
