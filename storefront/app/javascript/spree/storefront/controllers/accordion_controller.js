import AccordionController from '@kanety/stimulus-accordion'

export default class extends AccordionController {
  static values = {
    storeKey: String,
    closeOthers: Boolean
  }

  toggle(e) {
    const closeOthers = this.hasCloseOthersValue ? this.closeOthersValue : true
    this.togglers.forEach((toggler) => {
      if (toggler.contains(e.target)) {
        if (this.isOpened(toggler)) {
          this.close(toggler)
        } else {
          this.open(toggler)
        }
      } else if (this.isOpened(toggler) && closeOthers) {
        this.close(toggler)
      }
    })

    e.preventDefault()
  }
}
