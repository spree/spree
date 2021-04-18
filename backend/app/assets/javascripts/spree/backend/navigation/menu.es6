/* eslint-disable no-new */

document.addEventListener('DOMContentLoaded', function() {
  const menuItemSortable = {
    group: {
      name: 'sortable-menu-sub',
      pull: true,
      put: true
    },
    handle: '.move-handle',
    swapThreshold: 0.5,
    emptyInsertThreshold: 8,
    dragClass: 'menu-item-dragged',
    draggable: '.dragable',
    animation: 350,
    forceFallback: true,
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

function handleMenuItemMove(evt, successCallback) {
  const movedItem = evt.item.dataset.itemId
  const newParentId = evt.to.dataset.parentId
  const newPosition = evt.newIndex

  fetch(Spree.routes.menus_items_api_v2 + `?moved_item_id=${movedItem}&new_parent_id=${newParentId}&new_position_idx=${newPosition}`, {
    method: 'PATCH',
    headers: Spree.apiV2Authentication()
  })
    .then(response => {
      console.log(response);
    })
    .catch(err => {
      console.error(err);
    });
}
