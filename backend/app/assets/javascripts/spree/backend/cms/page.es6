document.addEventListener('DOMContentLoaded', function() {
  const pageVisabilityAttribute = document.querySelectorAll('[data-cms-page-id]')
  const pageTypeSelector = document.getElementById('cms_page_type')
  const el = document.getElementById('cmsPagesectionsArea')

  if (pageTypeSelector) updateCmsPageType()

  $(pageTypeSelector).on('change', function() { updateCmsPageType() })

  if (el) {
    Sortable.create(el, {
      handle: '.move-handle',
      ghostClass: 'moving-this',
      animation: 550,
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true,
      onEnd: function(evt) {
        handleSectionReposition(evt)
      }
    })
  }

  pageVisabilityAttribute.forEach(function(elem) {
    elem.addEventListener('change', function() {
      handleTogglePageVisibility(this)
    })
  })
})

function handleTogglePageVisibility(obj) {
  const pageId = parseInt(obj.dataset.cmsPageId, 10)
  const data = { page_id: pageId }

  fetch(Spree.routes.pages_api_v2 + `/${pageId}/toggle_visibility`, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      if (response.ok) {
        reloadPreview()
        toggleVisibilityState(obj)
      } else {
        // eslint-disable-next-line no-undef
        spreeHandleApiRequestError(response)
      }
    })
    .catch(err => { console.error(err) })
}

function toggleVisibilityState(obj) {
  const statusHolder = document.getElementById('visibilityStatus')
  const pageHidden = statusHolder.querySelector('.page_hidden')

  if (obj.checked) {
    pageHidden.classList.add('d-none')
  } else {
    pageHidden.classList.remove('d-none')
  }
}

function reloadPreview() {
  const liveLiewArea = document.getElementById('pageLivePreview')

  if (!liveLiewArea) return

  liveLiewArea.contentWindow.location.reload();
}

function handleSectionReposition(evt) {
  const data = {
    section_id: parseInt(evt.item.dataset.sectionId, 10),
    new_position_idx: parseInt(evt.newIndex, 10)
  }

  fetch(Spree.routes.sections_api_v2 + '/reposition', {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      if (response.ok) {
        reloadPreview()
      } else {
        // eslint-disable-next-line no-undef
        spreeHandleApiRequestError(response.status)
      }
    })
    .catch(err => { console.error(err) })
}

function updateCmsPageType() {
  const slugField = document.getElementById('cms_page_slug')
  const updatePageType = document.getElementById('updatePageType')

  if (!slugField) return

  const selectedLinkType = $('#cms_page_type').val()

  if (selectedLinkType === 'Spree::Cms::Pages::Homepage') {
    slugField.disabled = true
  } else {
    slugField.disabled = false
  }

  if (!updatePageType) return

  const existingType = updatePageType.dataset.pageType

  if (selectedLinkType === existingType) {
    updatePageType.classList.add('d-none')
  } else {
    updatePageType.classList.remove('d-none')
  }
}
