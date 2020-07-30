/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

/* global AUTH_TOKEN, order_number, Sortable, flatpickr, DOMPurify */

//= require spree/backend/flatpickr_locals

jQuery(function ($) {
  // Add some tips
  $('.with-tip').each(function() {
    $(this).tooltip({
      container: $(this)
    })
  })

  $('.with-tip').on('show.bs.tooltip', function(event) {
    if (('ontouchstart' in window)) {
      event.preventDefault()
    }
  })

  $('.js-show-index-filters').click(function () {
    $('.filter-well').slideToggle()
    $(this).parents('.filter-wrap').toggleClass('collapsed')
  })

  // Responsive Menus
  var body  = $('body')
  var modalBackdrop  = $('#multi-backdrop')

  // Fail safe on resize
  var resizeTimer;
  window.addEventListener('resize', function () {
    document.body.classList.remove('modal-open', 'sidebar-open', 'contextualSideMenu-open');
    document.body.classList.add('resize-animation-stopper');
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      document.body.classList.remove('resize-animation-stopper');
    }, 400);
  });

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
  var contextualSidebarMenuClose = $('#contextual-menu-close')

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
  contextualSidebarMenuClose.click(toggleContextualMenu)

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
      var cleanLabel = DOMPurify.sanitize(label)

      filter = '<span class="js-filter badge badge-secondary" data-ransack-field="' + ransackFieldId + '">' + cleanLabel + '<i class="icon icon-cancel ml-2 js-delete-filter"></i></span>'
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
})

function handleAlert (element) {
  element.classList.add('animate__animated', 'animate__bounceInUp')
  element.addEventListener('animationend', function () {
    element.classList.remove('animate__bounceInUp')
    element.classList.add('animate__fadeOutDownBig', 'animate__delay-3s')
  })
}

// Triggers alert if required on document ready.
$(document).ready(function () {
  var element = document.querySelector('.flash-alert')

  if (element) {
    handleAlert(element)
  }
})

$.fn.visible = function (cond) { this[ cond ? 'show' : 'hide' ]() }
// Triggers alerts when requested by javascript.
// eslint-disable-next-line camelcase
function show_flash (type, message) {
  var cleanMessage = DOMPurify.sanitize(message)
  var existingAlert = document.querySelector('.flash-alert')

  if (existingAlert) {
    existingAlert.remove()
  }

  var flashDiv = $('.alert-' + type)
  if (flashDiv.length === 0) {
    flashDiv = $('<div class="d-flex justify-content-center position-fixed flash-alert">' +
                 '<div class="alert alert-' + type + ' mx-2">' + cleanMessage + '</div></div>')

    $('body').append(flashDiv)

    var ajaxFlashNotfication = document.querySelector('.flash-alert')
    handleAlert(ajaxFlashNotfication)
  }
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
  var dateFrom = flatpickr('.datePickerFrom', {
    time_24hr: true,
    dateFormat: Spree.translations.date_picker,
    monthSelectorType: 'static',
    onChange: function(selectedDates) {
      dateTo.set('minDate', selectedDates[0])
    }
  })

  var dateTo = flatpickr('.datePickerTo', {
    monthSelectorType: 'static',
    time_24hr: true,
    dateFormat: Spree.translations.date_picker,
    onChange: function(selectedDates) {
      dateFrom.set('maxDate', selectedDates[0])
    }
  })

  flatpickr('.datepicker', {
    monthSelectorType: 'static',
    time_24hr: true,
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
        dataType: 'script',
        complete: function() {
          el.blur()
        }
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
    } else {
      el.blur()
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
  var parentEl = document.getElementsByClassName("sortable")[0];
  if (parentEl) {
    var element = parentEl.querySelector('tbody')
  }

  if (element) {
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
