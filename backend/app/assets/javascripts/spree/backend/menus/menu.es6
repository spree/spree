/* eslint-disable no-new */

document.addEventListener('DOMContentLoaded', function() {
  const menuItemSortable = {
    group: {
      name: 'sortable-menu',
      pull: true,
      put: true
    },
    handle: '.move-handle',
    swapThreshold: 0.5,
    emptyInsertThreshold: 8,
    dragClass: 'menu-item-dragged',
    draggable: '.dragable',
    animation: 350,
    forceFallback: false,
    onEnd: function (evt) {
      handleMenuItemMove(evt)
    }
  }

  let containers = null;
  containers = document.querySelectorAll('.menu-container');

  for (let i = 0; i < containers.length; i++) {
    new Sortable(containers[i], menuItemSortable);
  }
})

function handleMenuItemMove(evt) {
  const data = {
    moved_item_id: parseInt(evt.item.dataset.itemId, 10),
    new_parent_id: parseInt(evt.to.dataset.parentId, 10) || null,
    new_position_idx: parseInt(evt.newIndex, 10)
  }

  fetch(Spree.routes.menus_items_api_v2 + '/reposition', {
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
