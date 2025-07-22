import CheckboxSelectAll from 'stimulus-checkbox-select-all'

export default class extends CheckboxSelectAll {
  static targets = ['totalPreTaxRefund']

  connect() {
    this.updateTotalRefundAmount()
  }

  toggle(event) {
    super.toggle(event)
    this.updateTotalRefundAmount()
  }

  refresh() {
    super.refresh()
    this.updateTotalRefundAmount()
  }

  updateTotalRefundAmount() {
    var totalPretaxRefund = 0
    this.checked.forEach((checkbox) => {
      const returnItemRow = checkbox.closest('tr')
      const refundAmountInput = returnItemRow.querySelector('.refund-amount-input')
      let amount = parseFloat(refundAmountInput.value)
      if (!Number.isFinite(amount)) {
        amount = 0
        refundAmountInput.value = 0
      }
      totalPretaxRefund += amount
    })

    const displayTotal = isNaN(totalPretaxRefund) ? '' : totalPretaxRefund.toFixed(2)
    this.totalPreTaxRefundTarget.innerText = displayTotal
  }

  updateSuggestedAmount = (event) => {
    const returnItemRow = event.target.closest('tr')
    const amount = this.calculateSuggestedAmount(returnItemRow)
    returnItemRow.querySelector('.refund-amount-input').value = amount.toFixed(2)

    this.updateTotalRefundAmount()
  }

  calculateSuggestedAmount = (row) => {
    const returnQuantity = parseInt(row.querySelector('.refund-quantity-input').value, 10)
    const purchasedQuantity = parseInt(row.querySelector('.purchased-quantity').innerText, 10)
    const chargedAmount = parseFloat(row.querySelector('.charged-amount').dataset.chargedAmount)
    const amount = (returnQuantity / purchasedQuantity) * chargedAmount
    return amount
  }
}
