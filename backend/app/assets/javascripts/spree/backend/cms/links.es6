document.addEventListener('DOMContentLoaded', function() {
  const linkSwitcher = $('.link_switcher').select2()

  linkSwitcher.on('change', function() {
    const selectedLinkToValue = $(this).val()
    const linkSwitcherTarget = this.dataset.targetField || 'menu_item_link'
    const activePanel = document.querySelector(`div[data-panel-id='${linkSwitcherTarget}']`)
    const messagePanel = document.querySelector(`div[data-target-message-pannel='${linkSwitcherTarget}']`)
    const panelType = activePanel.dataset.panelType

    if (selectedLinkToValue === panelType) {
      activePanel.classList = ''
      activePanel.classList.add('d-block')

      messagePanel.classList = ''
      messagePanel.classList.add('d-none')
    } else {
      activePanel.classList = ''
      activePanel.classList.add('d-none')

      messagePanel.classList = ''
      messagePanel.classList.add('d-block')
    }
  })
})
