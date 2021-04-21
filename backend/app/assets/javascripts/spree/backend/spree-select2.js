document.addEventListener('DOMContentLoaded', function() {
  // Initiate a standard Select2 on any select element with the class .select2
  // Remember to add a place holder in the HTML as needed.
  $('select.select2').select2({})

  // Initiate a Select2 with the option to clear, on any select element with the class .select2-clear
  // Set: include_blank: true in the ERB.
  // A placeholder is auto-added here as it is required to clear the Select2.
  $('select.select2-clear').select2({
    placeholder: Spree.translations.select_an_option,
    allowClear: true
  })
})

$.fn.addSelect2Options = function (data) {
  var select = this

  function appendOption(select, data) {
    var option = null;
    if (data.attributes) {
      // API v2
      option = new Option(data.attributes.name, data.id, true, true)
    } else {
      // API v1
      option = new Option(data.name, data.id, true, true)
    }
    select.append(option).trigger('change')
  }

  if (Array.isArray(data)) {
    data.map(function(row) {
      appendOption(select, row)
    })
  } else {
    appendOption(select, data)
  }
  select.trigger({
    type: 'select2:select',
    params: {
      data: data
    }
  })
}

$.fn.select2.defaults.set('width', 'style')
$.fn.select2.defaults.set('dropdownAutoWidth', false)
$.fn.select2.defaults.set('theme', 'bootstrap4')

function formatSelect2Options(data) {
  var results = data.data.map(function (obj) {
    return {
      id: obj.id,
      text: obj.attributes.name
    }
  })

  return { results: results }
}
