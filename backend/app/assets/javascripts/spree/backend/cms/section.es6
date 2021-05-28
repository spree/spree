document.addEventListener('DOMContentLoaded', function() {
  const sectionKindSelector = $('#cms_section_type').select2()

  sectionKindSelector.on('change', function() {
    const selectedValue = $(sectionKindSelector).val()
    const message = document.getElementById('alertToClickUpdate')
    const activeSectionKind = document.getElementById('CmsSectionKind')
    const panelType = activeSectionKind.dataset.panelKind

    if (selectedValue === panelType) {
      activeSectionKind.classList = ''
      activeSectionKind.classList.add('d-block')

      message.classList = ''
      message.classList.add('d-none')
    } else {
      activeSectionKind.classList = ''
      activeSectionKind.classList.add('d-none')

      message.classList = ''
      message.classList.add('d-block')
    }
  });
})
