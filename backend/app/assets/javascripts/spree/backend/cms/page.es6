document.addEventListener('DOMContentLoaded', function() {
  const pageTypeSelector = document.getElementById('cms_page_type')
  const el = document.getElementById('cmsPagesectionsArea')

  if (pageTypeSelector) { updateCmsPageType() }

  if (el) {
    Sortable.create(el, {
      handle: '.move-handle',
      ghostClass: 'moving-this',
      animation: 550,
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true,
      onEnd: function (evt) {
        handleSectionReposition(evt)
      }
    })
  }

  $(pageTypeSelector).on('change', function() {
    updateCmsPageType()
  });

  function updateCmsPageType () {
    const slugField = document.getElementById('noHomePage')
    const updatePageType = document.getElementById('updatePageType')
    const existingType = updatePageType.dataset.pageType

    if (!slugField) return

    const selectedLinkType = $('#cms_page_type').val()

    if (selectedLinkType === existingType) {
      updatePageType.classList.add('d-none')
    } else {
      updatePageType.classList.remove('d-none')
    }

    if (selectedLinkType === 'Spree::Cms::Pages::Homepage') {
      slugField.classList.add('d-none')
    } else {
      slugField.classList.remove('d-none')
    }
  }
})

function handleSectionReposition(evt) {
  const data = {
    section_id: parseInt(evt.item.dataset.sectionId, 10),
    new_position_idx: parseInt(evt.newIndex, 10)
  }

  fetch(Spree.routes.section_reposition_api_v2, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      if (response.ok !== true) {
        handleMenuItemMoveError()
      }
    })
    .catch(err => {
      console.error(err);
    });
}

function handleMenuItemMoveError () {
  // eslint-disable-next-line no-undef
  show_flash('error', Spree.translations.move_could_not_be_saved)
}
