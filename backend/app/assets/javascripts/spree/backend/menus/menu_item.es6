document.addEventListener('DOMContentLoaded', function() {
  $('#LinkToSelect2').select2()

  $('#LinkToSelect2').on('change', function() {
    const selectedLinkTo = $('#LinkToSelect2').val()
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
