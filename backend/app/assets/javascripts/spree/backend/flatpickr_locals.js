/* global flatpickr */
document.addEventListener('DOMContentLoaded', function() {
  flatpickr.l10ns.default.firstDayOfWeek = Spree.translations.firstDay
  flatpickr.l10ns.default.rangeSeparator = Spree.translations.rangeSep
  flatpickr.l10ns.default.weekAbbreviation = Spree.translations.weekAbbr
  flatpickr.l10ns.default.scrollTitle = Spree.translations.scrollTitle
  flatpickr.l10ns.default.toggleTitle = Spree.translations.toggleTitle
  flatpickr.l10ns.default.amPM = [Spree.translations.am, Spree.translations.pm]
  flatpickr.l10ns.default.yearAriaLabel = Spree.translations.yearAriaLabel
  flatpickr.l10ns.default.hourAriaLabel = Spree.translations.hourAriaLabel
  flatpickr.l10ns.default.minuteAriaLabel = Spree.translations.minuteAriaLabel
  flatpickr.l10ns.default.weekdays = {
    shorthand: [
      Spree.translations.sun,
      Spree.translations.mon,
      Spree.translations.tue,
      Spree.translations.wed,
      Spree.translations.thu,
      Spree.translations.fri,
      Spree.translations.sat]
  }
  flatpickr.l10ns.default.months = {
    longhand: [
      Spree.translations.lh_jan,
      Spree.translations.lh_feb,
      Spree.translations.lh_mar,
      Spree.translations.lh_apr,
      Spree.translations.lh_may,
      Spree.translations.lh_jun,
      Spree.translations.lh_jul,
      Spree.translations.lh_aug,
      Spree.translations.lh_sep,
      Spree.translations.lh_oct,
      Spree.translations.lh_nov,
      Spree.translations.lh_dec]
  }
})
