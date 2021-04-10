/* eslint-disable no-new */

document.addEventListener('DOMContentLoaded', function() {
  const menuItemSortable = {
    group: {
      name: 'sortable-menu-sub',
      pull: true,
      put: true
    },
    handle: '.move-handle',
    dragClass: 'menu-item-dragged',
    draggable: '.dragable',
    animation: 350,
    forceFallback: false
  };

  let containers = null;
  containers = document.querySelectorAll('.menu-container');

  for (let i = 0; i < containers.length; i++) {
    new Sortable(containers[i], menuItemSortable);
  }
})
