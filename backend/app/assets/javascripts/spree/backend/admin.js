/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

/* global AUTH_TOKEN, order_number, Sortable, flatpickr */

//= require spree/backend/flatpickr_locals

jQuery(function ($) {
  // Add some tips
  $('.with-tip').each(function() {
    $(this).tooltip({
      container: $(this)
    })
  })

  $('.js-show-index-filters').click(function () {
    $('.filter-well').slideToggle()
    $(this).parents('.filter-wrap').toggleClass('collapsed')
  })

  // Responsive Menus
  var body  = $('body')
  var modalBackdrop  = $('#multi-backdrop')

  // Fail safe on resize
  document.getElementsByTagName("BODY")[0].onresize = function() { closeAllMenus() }

  function closeAllMenus() {
    body.removeClass()
    body.addClass('admin')
    modalBackdrop.removeClass('show')
  }

  modalBackdrop.click(closeAllMenus)

  // Main Menu Functionality
  var sidebarOpen    = $('#sidebar-open')
  var sidebarClose   = $('#sidebar-close')
  var activeItem     = $('#main-sidebar').find('.selected')

  activeItem.closest('.nav-sidebar').addClass('active-option')
  activeItem.closest('.nav-pills').addClass('in show')

  function openMenu() {
    closeAllMenus()
    body.addClass('sidebar-open modal-open')
    modalBackdrop.addClass('show')
  }
  sidebarOpen.click(openMenu)
  sidebarClose.click(closeAllMenus)

  // Contextual Sidebar Menu
  var contextualSidebarMenuToggle = $('#contextual-menu-toggle')

  function toggleContextualMenu() {
    if (document.body.classList.contains('contextualSideMenu-open')) {
      closeAllMenus()
    } else {
      closeAllMenus()
      body.addClass('contextualSideMenu-open modal-open')
      modalBackdrop.addClass('show')
    }
  }
  contextualSidebarMenuToggle.click(toggleContextualMenu)

  // TODO: remove this js temp behaviour and fix this decent
  // Temp quick search
  // When there was a search term, copy it
  $('.js-quick-search').val($('.js-quick-search-target').val())
  // Catch the quick search form submit and submit the real form
  $('#quick-search').submit(function () {
    $('.js-quick-search-target').val($('.js-quick-search').val())
    $('#table-filter form').submit()
    return false
  })

  // Clickable ransack filters
  $('.js-add-filter').click(function () {
    var ransackField = $(this).data('ransack-field')
    var ransackValue = $(this).data('ransack-value')

    $('#' + ransackField).val(ransackValue)
    $('#table-filter form').submit()
  })

  $(document).on('click', '.js-delete-filter', function () {
    var ransackField = $(this).parents('.js-filter').data('ransack-field')

    $('#' + ransackField).val('')
    $('#table-filter form').submit()
  })

  function ransackField (value) {
    switch (value) {
      case 'Date Range':
        return 'Start'
      case '':
        return 'Stop'
      default:
        return value.trim()
    }
  }

  $('.js-filterable').each(function () {
    var $this = $(this)

    if ($this.val()) {
      var ransackValue, filter
      var ransackFieldId = $this.attr('id')
      var label = $('label[for="' + ransackFieldId + '"]')

      if ($this.is('select')) {
        ransackValue = $this.find('option:selected').text()
      } else {
        ransackValue = $this.val()
      }

      label = ransackField(label.text()) + ': ' + ransackValue

      filter = '<span class="js-filter badge badge-secondary" data-ransack-field="' + ransackFieldId + '">' + label + '<i class="icon icon-cancel ml-2 js-delete-filter"></i></span>'
      $(".js-filters").append(filter).show()
    }
  })

  // per page dropdown
  // preserves all selected filters / queries supplied by user
  // changes only per_page value
  $('.js-per-page-select').change(function () {
    var form = $(this).closest('.js-per-page-form')
    var url = form.attr('action')
    var value = $(this).val().toString()
    if (url.match(/\?/)) {
      url += '&per_page=' + value
    } else {
      url += '?per_page=' + value
    }
    window.location = url
  })

  // injects per_page settings to all available search forms
  // so when user changes some filters / queries per_page is preserved
  $(document).ready(function () {
    var perPageDropdown = $('.js-per-page-select:first')
    if (perPageDropdown.length) {
      var perPageValue = perPageDropdown.val().toString()
      var perPageInput = '<input type="hidden" name="per_page" value=' + perPageValue + ' />'
      $('#table-filter form').append(perPageInput)
    }
  })

  // Make flash messages disappear
  setTimeout(function () { $('.alert-auto-disappear').slideUp() }, 5000)
})

$.fn.visible = function (cond) { this[ cond ? 'show' : 'hide' ]() }
// eslint-disable-next-line camelcase
function show_flash (type, message) {
  var flashDiv = $('.alert-' + type)
  if (flashDiv.length === 0) {
    flashDiv = $('<div class="alert alert-' + type + '" />')
    $('#content').prepend(flashDiv)
  }
  flashDiv.html(message).show().delay(10000).slideUp()
}

// Apply to individual radio button that makes another element visible when checked
$.fn.radioControlsVisibilityOfElement = function (dependentElementSelector) {
  if (!this.get(0)) { return }
  var showValue = this.get(0).value
  var radioGroup = $("input[name='" + this.get(0).name + "']")
  radioGroup.each(function () {
    $(this).click(function () {
      // eslint-disable-next-line eqeqeq
      $(dependentElementSelector).visible(this.checked && this.value == showValue)
    })
    if (this.checked) { this.click() }
  })
}

document.addEventListener('DOMContentLoaded', function() {
  // This javascript needs re-writing to target paris of input fields
  // within a div allowing you to have multiple instances of From To cals
  // on a single page, and only the relevent cal is updated.
  var target = document.querySelector('.datePickerFrom')
  var targetTime = document.querySelector('.dateTimePickerFrom')

  if (target) {
    var targetDate = target.getElementsByTagName('input')[0].value
  }
  
  if (targetTime) {
    var targetDate = targetTime.getElementsByTagName('input')[0].value
  }

  flatpickr('.datePickerSingle', {
    wrap: true,
    monthSelectorType: 'static',
    ariaDateFormat: Spree.translations.date_picker,
    disableMobile: true,
    dateFormat: Spree.translations.date_picker
  })

  var dateFrom = flatpickr('.datePickerFrom', {
    wrap: true,
    monthSelectorType: 'static',
    ariaDateFormat: Spree.translations.date_picker,
    disableMobile: true,
    dateFormat: Spree.translations.date_picker,
    onChange: function(selectedDates) {
      dateTo.set('minDate', selectedDates[0])
    }
  })

  var dateTo = flatpickr('.datePickerTo', {
    wrap: true,
    monthSelectorType: 'static',
    ariaDateFormat: Spree.translations.date_picker,
    disableMobile: true,
    dateFormat: Spree.translations.date_picker,
    minDate: targetDate,
    onReady: function(selectedDates) {
      dateFrom.set('maxDate', selectedDates[0])
    },
    onChange: function(selectedDates) {
      dateFrom.set('maxDate', selectedDates[0])
    }
  })

  var dateTimeSingle = flatpickr('.dateTimePickerSingle', {
    wrap: true,
    enableTime: true,
    dateFormat: Spree.translations.date_picker + " H:i",
    time_24hr: true,
    monthSelectorType: 'static',
    disableMobile: true,
  })

  var dateTimeFrom = flatpickr('.dateTimePickerFrom', {
    wrap: true,
    enableTime: true,
    dateFormat: Spree.translations.date_picker + " - H:i",
    time_24hr: true,
    monthSelectorType: 'static',
    disableMobile: true,
    onChange: function(selectedDates) {
      dateTimeTo.set('minDate', selectedDates[0])
    }
  })

  var dateTimeTo = flatpickr('.dateTimePickerTo', {
    wrap: true,
    enableTime: true,
    monthSelectorType: 'static',
    time_24hr: true,
    disableMobile: true,
    dateFormat: Spree.translations.date_picker + " - H:i",
    minDate: targetDate,
    onReady: function(selectedDates) {
      dateTimeFrom.set('maxDate', selectedDates[0])
    },
    onChange: function(selectedDates) {
      dateTimeFrom.set('maxDate', selectedDates[0])
    }
  })

  // For backwards compatability in extensions
  flatpickr('.datepicker', {
    monthSelectorType: 'static',
    ariaDateFormat: Spree.translations.date_picker,
    disableMobile: true,
    dateFormat: Spree.translations.date_picker
  })
})

$(document).ready(function() {
  $('.observe_field').on('change', function() {
    target = $(this).data('update')
    $(target).hide()
    $.ajax({
      dataType: 'html',
      url: $(this).data('base-url') + encodeURIComponent($(this).val()),
      type: 'GET'
    }).done(function (data) {
      $(target).html(data)
      $(target).show()
    })
  })

  var uniqueId = 1
  $('.spree_add_fields').click(function () {
    var target = $(this).data('target')
    var newTableRow = $(target + ' tr:visible:last').clone()
    var newId = new Date().getTime() + (uniqueId++)
    newTableRow.find('input, select').each(function () {
      var el = $(this)
      el.val('')
      el.prop('id', el.prop('id').replace(/\d+/, newId))
      el.prop('name', el.prop('name').replace(/\d+/, newId))
    })
    // When cloning a new row, set the href of all icons to be an empty "#"
    // This is so that clicking on them does not perform the actions for the
    // duplicated row
    newTableRow.find('a').each(function () {
      var el = $(this)
      el.prop('href', '#')
    })
    $(target).prepend(newTableRow)
  })

  $('body').on('click', '.delete-resource', function () {
    var el = $(this)
    if (confirm(el.data('confirm'))) {
      $.ajax({
        type: 'POST',
        url: $(this).prop('href'),
        data: {
          _method: 'delete',
          authenticity_token: AUTH_TOKEN
        },
        dataType: 'script'
      }).done(function () {
        var $flash_element = $('.alert-success')
        if ($flash_element.length) {
          el.parents('tr').fadeOut('hide', function () {
            $(this).remove()
          })
        }
      }).fail(function (response) {
        show_flash('error', response.responseText)
      })
    }
    return false
  })

  $('body').on('click', 'a.spree_remove_fields', function () {
    el = $(this)
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
      }).done(function () {
        el.parents('tr').fadeOut('hide', function () {
          $(this).remove()
        })
      }).fail(function (response) {
        show_flash('error', response.responseText)
      })
    }
    return false
  })

  $('body').on('click', '.select_properties_from_prototype', function() {
    $('#busy_indicator').show()
    var clicked_link = $(this)
    $.ajax({
      dataType: 'script',
      url: clicked_link.prop('href'),
      type: 'GET'
    }).done(function () {
      clicked_link.parent('td').parent('tr').hide()
      $('#busy_indicator').hide()
    })
    return false
  })

  // Sortable List Up-Down
  var element = document.getElementById('sortVert')
  if (element !== null && element !== '') {
    Sortable.create(element, {
      handle: '.move-handle',
      animation: 550,
      ghostClass: 'bg-light',
      dragClass: "sortable-drag-v",
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true,
      onEnd: function (evt) {
        var itemEl = evt.item
        var positions = { authenticity_token: AUTH_TOKEN }
        $.each($('tr', element), function(position, obj) {
          reg = /spree_(\w+_?)+_(\d+)/
          parts = reg.exec($(obj).prop('id'))
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

  // Close notifications
  $('a.dismiss').click(function () {
    $(this).parent().fadeOut()
  })

  // Utility
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
