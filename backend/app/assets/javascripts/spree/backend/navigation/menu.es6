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
      const newParentId = evt.to.dataset.parentId
      const position = evt.newIndex
    }
  };

  let containers = null;
  containers = document.querySelectorAll('.menu-container');

  for (let i = 0; i < containers.length; i++) {
    new Sortable(containers[i], menuItemSortable);
  }
})
