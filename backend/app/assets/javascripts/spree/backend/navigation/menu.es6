/* eslint-disable no-new */
document.addEventListener('DOMContentLoaded', function() {
  const menuItemSortable = {
    group: {
      name: 'sortable-list-2',
      pull: true,
      put: true
    },
    handle: '.move-handle',
    draggable: '.dragable',
    animation: 250,
    forceFallback: true
  };

  let containers = null;
  containers = document.querySelectorAll('.menu-container');

  for (let i = 0; i < containers.length; i++) {
    new Sortable(containers[i], menuItemSortable);
  }
})
