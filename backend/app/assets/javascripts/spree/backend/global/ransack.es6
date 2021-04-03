document.addEventListener('DOMContentLoaded', function() {
  const QuickSearchInput = document.getElementById('quick_search')

  if (QuickSearchInput) {
    const QuickSearchPlaceHolder = QuickSearchInput.placeholder
    const TargetSearchFieldId = document.querySelector('input.js-quick-search-target').id
    const AssociatedLabelName = document.querySelector(`label[for="${TargetSearchFieldId}"]`).innerHTML

    QuickSearchInput.placeholder = `${QuickSearchPlaceHolder} ${AssociatedLabelName}`
  }

  $('.js-show-index-filters').click(function() {
    $('.filter-well').slideToggle()
    $(this).parents('.filter-wrap').toggleClass('collapsed')
  })

  // TODO: remove this js temp behaviour and fix this decent
  // Temp quick search
  // When there was a search term, copy it
  $('.js-quick-search').val($('.js-quick-search-target').val())

  // Catch the quick search form submit and submit the real form
  $('#quick-search').submit(function() {
    $('.js-quick-search-target').val($('.js-quick-search').val())
    $('#table-filter form').submit()
    return false
  })

  // Clickable ransack filters
  $('.js-add-filter').click(function() {
    var ransackField = $(this).data('ransack-field')
    var ransackValue = $(this).data('ransack-value')

    $('#' + ransackField).val(ransackValue)
    $('#table-filter form').submit()
  })

  $(document).on('click', '.js-delete-filter', function() {
    var ransackField = $(this).parents('.js-filter').data('ransack-field')

    $('#' + ransackField).val('')
    $('#table-filter form').submit()
  })

  function ransackField(value) {
    switch (value) {
      case 'Date Range':
        return 'Start'
      case '':
        return 'Stop'
      default:
        return value.trim()
    }
  }

  // To appear in the filtered options, the elements id attribute must start with 'q_',
  // and it must have the class'.js-filterable'.
  $('[id^="q_"].js-filterable').each(function() {
    var $this = $(this)

    if ($this.val() !== null && $this.val() !== '' && $this.val().length !== 0) {
      var ransackValue, filter
      var ransackFieldId = $this.attr('id')
      var label = $('label[for="' + ransackFieldId + '"]')

      if ($this.is('select')) {
        ransackValue = $this.find('option:selected').toArray().map(function(option) {
          return option.text;
        }).join(', ')
      } else {
        ransackValue = $this.val()
      }

      label = ransackField(label.text()) + ': ' + ransackValue

      var cleanLabel = DOMPurify.sanitize(label)

      filter = '<span class="js-filter badge badge-secondary" data-ransack-field="' + ransackFieldId + '">' + cleanLabel + '<i class="icon icon-cancel ml-2 js-delete-filter"></i></span>'
      $('.js-filters').append(filter).show()
    }
  })

  // per page dropdown
  // preserves all selected filters / queries supplied by user
  // changes only per_page value
  $('.js-per-page-select').change(function() {
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
  $(document).ready(function() {
    var perPageDropdown = $('.js-per-page-select:first')
    if (perPageDropdown.length) {
      var perPageValue = perPageDropdown.val().toString()
      var perPageInput = '<input type="hidden" name="per_page" value=' + perPageValue + ' />'
      $('#table-filter form').append(perPageInput)
    }
  })
})
