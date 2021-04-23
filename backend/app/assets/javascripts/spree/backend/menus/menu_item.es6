document.addEventListener('DOMContentLoaded', function() {
  $('#menu_item_linked_resource_type').select2()
  $('#menu_item_item_type').select2()

  $('#menu_item_linked_resource_type').on('change', function() {
    const selectedLinkTo = $('#menu_item_linked_resource_type').val()
    const message = document.getElementById('alertToClickUpdate')
    const activePanel = document.getElementById('linkResourcePanel')
    const panelType = activePanel.dataset.panelType

    if (selectedLinkTo === panelType) {
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
  });

  updateContainerMessage()

  $('#menu_item_item_type').on('change', function() {
    updateContainerMessage()
  });

  function updateContainerMessage () {
    const linkSettingsPanel = document.getElementById('LinkSettings')

    if (!linkSettingsPanel) return

    const selectedLinkType = $('#menu_item_item_type').val()

    const usingConainerMessage = document.getElementById('usingContainerInfo')

    if (selectedLinkType === 'Container') {
      linkSettingsPanel.classList.add('d-none')
      usingConainerMessage.classList.remove('d-none')
    } else {
      linkSettingsPanel.classList.remove('d-none')
      usingConainerMessage.classList.add('d-none')
    }
  }
})
