document.addEventListener('DOMContentLoaded', function() {
  flatpickr.setDefaults({
    altInput: true,
    time_24hr: true,
    altInputClass: 'flatpickr-alt-input',
    locale: Spree.translations.flatpickr_locale
  })

  const dateFrom = flatpickr('.datePickerFrom', {
    onChange: function(selectedDates) {
      dateTo.set('minDate', selectedDates[0])
    }
  })

  const dateTo = flatpickr('.datePickerTo', {
    onChange: function(selectedDates) {
      dateFrom.set('maxDate', selectedDates[0])
    }
  })

  flatpickr('.datepicker', {})
})
