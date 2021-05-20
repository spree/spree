document.addEventListener('DOMContentLoaded', function() {
  $('#cms_section_linked_resource_type').select2()
  $('#cms_section_item_type').select2()

  $('#cms_section_linked_resource_type').on('change', function() {
    const selectedLinkTo = $('#cms_section_linked_resource_type').val()
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


})
