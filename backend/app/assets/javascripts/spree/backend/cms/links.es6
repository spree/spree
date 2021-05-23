document.addEventListener('DOMContentLoaded', function() {
  const linkSwitcher = $('.link_switcher').select2()

  linkSwitcher.on('change', function() {
    const selectedLinkToValue = $(linkSwitcher).val()
    const message = document.getElementById('linkClickUpdate')
    const activePanel = document.querySelector('[data-panel-type]')
    const panelType = activePanel.dataset.panelType

    if (selectedLinkToValue === panelType) {
      activePanel.classList = ''
      activePanel.classList.add('d-block')

      message.classList = ''
      message.classList.add('d-none')
    } else {
      activePanel.classList = ''
      activePanel.classList.add('d-none')

      message.classList = ''
      message.classList.add('d-block')
    }
  })
})
