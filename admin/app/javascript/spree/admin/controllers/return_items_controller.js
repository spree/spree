import CheckboxSelectAll from 'stimulus-checkbox-select-all'

export default class extends CheckboxSelectAll {
  connect() {

    var formFields = $(this.element)



    this.updateSuggestedAmount()

    formFields.find('input#select-all').on('change', function (ev) {
      var checkBoxes = $(ev.currentTarget).parents('table:first').find('input.add-item')
      checkBoxes.prop('checked', this.checked)
      this.updateSuggestedAmount()
    })

    formFields.find('input.add-item').on('change', this.updateSuggestedAmount)

    formFields.find('input, select').not('.add-item').on('change', checkAddItemBox)
  }

  updateSuggestedAmount = () => {
    var totalPretaxRefund = 0
    var checkedItems = this.element.querySelectorAll('input.add-item:checked')
    $.each(checkedItems, function (i, checkbox) {
      var returnItemRow = $(checkbox).parents('tr')
      var returnQuantity = parseInt(returnItemRow.find('.refund-quantity-input').val(), 10)
      var purchasedQuantity = parseInt(returnItemRow.find('.purchased-quantity').text(), 10)
      var amount = (returnQuantity / purchasedQuantity) * parseFloat(returnItemRow.find('.charged-amount').data('chargedAmount'))
      returnItemRow.find('.refund-amount-input').val(amount.toFixed(2))
      totalPretaxRefund += amount
    })

    var displayTotal = isNaN(totalPretaxRefund) ? '' : totalPretaxRefund.toFixed(2)
    this.element.querySelector('span#total_pre_tax_refund').innerText = displayTotal
  }
}
