/* global order_number, show_flash */

$(document).ready(function() {
  /**
    OBSERVE FIELD:
  **/
  $('.observe_field').on('change', function() {
    var target = $(this).data('update')
    $(target).hide()
    $.ajax({
      dataType: 'html',
      url: $(this).data('base-url') + encodeURIComponent($(this).val()),
      type: 'GET'
    }).done(function(data) {
      $(target).html(data)
      $(target).show()
    })
  })

  /**
    ADD FIELDS
  **/
  var uniqueId = 1
  $('.spree_add_fields').click(function() {
    var target = $(this).data('target')
    var newTableRow = $(target + ' tr:visible:last').clone()
    var newId = new Date().getTime() + (uniqueId++)
    newTableRow.find('input, select').each(function() {
      var el = $(this)
      el.val('')
      el.prop('id', el.prop('id').replace(/\d+/, newId))
      el.prop('name', el.prop('name').replace(/\d+/, newId))
    })

    // When cloning a new row, set the href of all icons to be an empty "#"
    // This is so that clicking on them does not perform the actions for the
    // duplicated row
    newTableRow.find('a').each(function() {
      var el = $(this)
      el.prop('href', '#')
    })
    $(target).prepend(newTableRow)
  })

  /**
    DELETE RESOURCE
  **/
  $('body').on('click', '.delete-resource', function() {
    var el = $(this)
    if (confirm(el.data('confirm'))) {
      $.ajax({
        type: 'POST',
        url: $(this).prop('href'),
        data: {
          _method: 'delete',
          authenticity_token: AUTH_TOKEN
        },
        dataType: 'script',
        complete: function() {
          el.blur()
        }
      }).done(function() {
        var $flashElement = $('#FlashAlertsContainer span[data-alert-type="success"]')
        if ($flashElement.length) {
          el.parents('tr').fadeOut('hide', function() {
            $(this).remove()
          })
        }
      }).fail(function(response) {
        show_flash('error', response.responseText)
      })
    } else {
      el.blur()
    }
    return false
  })

  /**
    REMOVE FIELDS
  **/
  $('body').on('click', 'a.spree_remove_fields', function() {
    var el = $(this)
    el.prev('input[type=hidden]').val('1')
    el.closest('.fields').hide()
    if (el.prop('href').substr(-1) === '#') {
      el.parents('tr').fadeOut('hide')
    } else if (el.prop('href')) {
      $.ajax({
        type: 'POST',
        url: el.prop('href'),
        data: {
          _method: 'delete',
          authenticity_token: AUTH_TOKEN
        }
      }).done(function() {
        el.parents('tr').fadeOut('hide', function() {
          $(this).remove()
        })
      }).fail(function(response) {
        show_flash('error', response.responseText)
      })
    }
    return false
  })

  /**
    SELECT PROPERTIES FROM PROTOTYPE
  **/
  $('body').on('click', '.select_properties_from_prototype', function() {
    $('#busy_indicator').show()
    var clickedLink = $(this)
    $.ajax({
      dataType: 'script',
      url: clickedLink.prop('href'),
      type: 'GET'
    }).done(function() {
      clickedLink.parent('td').parent('tr').hide()
      $('#busy_indicator').hide()
    })
    return false
  })

  /**
    UTILITY
  **/
  window.Spree.advanceOrder = function() {
    $.ajax({
      type: 'PUT',
      async: false,
      data: {
        token: Spree.api_key
      },
      url: Spree.url(Spree.routes.checkouts_api + '/' + order_number + '/advance')
    }).done(function() {
      window.location.reload()
    })
  }
})
