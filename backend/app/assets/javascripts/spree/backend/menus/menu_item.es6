document.addEventListener('DOMContentLoaded', function() {
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
