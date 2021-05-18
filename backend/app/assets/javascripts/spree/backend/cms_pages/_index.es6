document.addEventListener('DOMContentLoaded', function() {
const el = document.getElementById('cmsPagesectionsArea')

  if (el) {
    Sortable.create(el, {
      handle: '.move-handle',
      ghostClass: 'moving-this',
      animation: 550,
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true
      // onEnd: function (evt) {
      //   var itemEl = evt.item.getAttribute('data-section-id')
      //   var newin = evt.newIndex
      //   return $.ajax({
      //     url: Spree.routes.classifications_api,
      //     method: 'PUT',
      //     dataType: 'json',
      //     data: {
      //       token: Spree.api_key,
      //       product_id: itemEl,
      //       taxon_id: $('#taxon_id').val(),
      //       position: newin
      //     }
      //   })
      // }
    })
  }
})
