$(@).ready( ->
  $('[data-hook=general_settings_clear_cache] #clear_cache').click ->
    response = confirm(Spree.translations.are_you_sure)
    if response
      $.ajax
        type: 'POST'
        url: Spree.routes.clear_cache
        success: ->
          show_flash 'success', "Cache was flushed."
        error: (msg) ->
          if msg.responseJSON["error"]
            show_flash 'error', msg.responseJSON["error"]
          else
            show_flash 'error', "There was a problem while flushing cache."
)
