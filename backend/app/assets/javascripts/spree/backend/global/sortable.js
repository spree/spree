document.addEventListener('DOMContentLoaded', function() {
  var parentEl = document.getElementsByClassName('sortable')[0];
  if (parentEl) {
    var element = parentEl.querySelector('tbody')
  }

  if (element) {
    Sortable.create(element, {
      handle: '.move-handle',
      animation: 550,
      ghostClass: 'bg-light',
      dragClass: 'sortable-drag-v',
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true,
      onEnd: function(evt) {
        var itemEl = evt.item
        var positions = { authenticity_token: AUTH_TOKEN }
        $.each($('tr', element), function(position, obj) {
          var reg = /spree_(\w+_?)+_(\d+)/
          var parts = reg.exec($(obj).prop('id'))
          if (parts) {
            positions['positions[' + parts[2] + ']'] = position + 1
          }
        })
        $.ajax({
          type: 'POST',
          dataType: 'json',
          url: $(itemEl).closest('table.sortable').data('sortable-link'),
          data: positions
        })
      }
    })
  }
})
