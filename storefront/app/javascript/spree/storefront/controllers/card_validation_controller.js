import { Controller } from "@hotwired/stimulus"
import valid from "card-validator"

export default class extends Controller {
  static targets = ["number", "expiry", "cvv", "typeContainer", "ccType"]

  connect() {
    this.numberTarget.addEventListener('input', this.validateCard.bind(this))
    this.expiryTarget.addEventListener('input', this.validateExpiry.bind(this))
    this.cvvTarget.addEventListener('input', this.validateCVV.bind(this))
  }

  validateCard(event) {
    let value = event.target.value.replace(/\D/g, '')
    const validation = valid.number(value)

    // Format the card number with spaces
    if (validation.card) {
      const gaps = validation.card.gaps
      let formatted = ''
      let currentPosition = 0

      // Add spaces based on the card type's gap positions
      for (let i = 0; i < value.length; i++) {
        if (gaps.includes(i)) {
          formatted += ' '
        }
        formatted += value[i]
      }

      // Update input value with formatted number
      event.target.value = formatted.trim()
    } else {
      // Default formatting for unknown card types (4 digit groups)
      event.target.value = value.replace(/(.{4})/g, '$1 ').trim()
    }

    if (validation.isPotentiallyValid) {
      event.target.classList.remove('invalid')
    } else {
      event.target.classList.add('invalid')
    }

    if (validation.card) {
      // Update CVV validation length based on card type
      this.cvvTarget.setAttribute('maxlength', validation.card.code.size)

      // Update card type field and icon
      const cardType = validation.card.type
      this.ccTypeTarget.value = cardType.replace(/-/g, '_')
      this.updateCardIcon(cardType)
    } else {
      this.ccTypeTarget.value = ''
      this.typeContainerTarget.innerHTML = ''
    }
  }

  updateCardIcon(cardType) {
    cardType = (cardType === "mastercard" ? "master" : cardType)

    const iconElement = document.getElementById(`credit-card-icon-${cardType}`)
    if (iconElement) {
      this.typeContainerTarget.innerHTML = iconElement.innerHTML
    } else {
      this.typeContainerTarget.innerHTML = ''
    }
  }

  validateExpiry(event) {
    let input = event.target.value.replace(/\D/g, '').substring(0, 6)

    // Format as MM/YYYY
    if (input.length > 2) {
      input = input.substring(0, 2) + '/' + input.substring(2)
    }

    // Validate month
    const monthValue = parseInt(input.substring(0, 2))
    if (monthValue > 12) {
      input = '12' + input.substring(2)
    }

    event.target.value = input

    const [month, year] = input.split('/')
    const validation = valid.expirationDate({ month, year })

    if (validation.isPotentiallyValid) {
      event.target.classList.remove('invalid')
    } else {
      event.target.classList.add('invalid')
    }
  }

  validateCVV(event) {
    const cvv = event.target.value
    const validation = valid.cvv(cvv)

    if (validation.isPotentiallyValid) {
      event.target.classList.remove('invalid')
    } else {
      event.target.classList.add('invalid')
    }
  }
}
