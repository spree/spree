/* global show_flash */
$(function () {
  $('[data-hook=general_settings_clear_cache] #clear_cache').click(function () {
    if (confirm(Spree.translations.are_you_sure)) {
      $.ajax({
        type: 'POST',
        url: Spree.routes.clear_cache,
        data: {
          authenticity_token: AUTH_TOKEN
        },
        dataType: 'json'
      }).done(function () {
        show_flash('success', 'Cache was flushed.')
      })
        .fail(function (message) {
          if (message.responseJSON['error']) {
            show_flash('error', message.responseJSON['error'])
          } else {
            show_flash('error', 'There was a problem while flushing cache.')
          }
        })
    }
  })
})
