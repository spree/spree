document.addEventListener('DOMContentLoaded', function() {
const el = document.getElementById('cmsPagesectionsArea')

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
