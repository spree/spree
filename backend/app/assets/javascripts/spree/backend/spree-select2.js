document.addEventListener('DOMContentLoaded', function() {
  // Inititate Select2 on any select element with the class .select2
  $('select.select2').select2({
    // change that
    allowClear: false,
    placeholder: {
      id: '-1', // the value of the option
      text: 'Select an option'
    }
  })
})

$.fn.addSelect2Options = function (data) {
  var select = this

  function appendOption(select, data) {
    var option = new Option(data.name, data.id, true, true)
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
