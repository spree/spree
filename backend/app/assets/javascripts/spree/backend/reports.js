/**
 * @typedef DateRangeName
 * @type {('last_thirty_days'|'this_week'|'last_week'|'this_month'|'last_month'|'this_year'|'last_year')}
 */

/**
 * @typedef DateRange
 * @type {object}
 * @property {string} min - Completed At Min
 * @property {string} max - Completed At Max
 */

// IE11 Polyfills
if (!String.prototype.includes) {
  String.prototype.includes = function (search, start) {
    'use strict'

    if (search instanceof RegExp) {
      throw TypeError('first argument must not be a RegExp')
    }
    if (start === undefined) { start = 0 }
    return this.indexOf(search, start) !== -1
  }
}

Spree.Reports = {
  FONT_FAMILY:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
  DATE_FORMAT: 'DD-MM-YYYY',

  /**
   * @param {string} className Class name of canvas dom nodes for charts
   * @returns {HTMLCollection} DOM nodes
   */
  getNodes: function (className) {
    return document.getElementsByClassName(className)
  },

  getUri: function () {
    return new Uri(window.location)
  },

  /**
   * @param {HTMLCanvasElement} node DOM node
   * @returns {object} Information to get chart data
   */
  getChartData: function (node) {
    return JSON.parse(JSON.stringify(node.dataset))
  },

  /**
   * @param {string} node DOM node id to hold the chart. Should be canvas.
   * @param {string} type Chart type.
   * @param {object} data Chart.js data objects holding labels and datasets to display
   * @returns {Chart}
   */
  createChart: function (node, data, options) {
    return new Chart(node, {
      type: options.type,
      data: data,
      options: {
        datasets: {
          line: {
            backgroundColor: options.bgColor || 'rgba(71, 141, 193, 0.8)',
            borderColor: options.lineColor || 'rgba(71, 141, 193, 1)'
          },
          bar: {
            backgroundColor: options.bgColor || 'rgba(71, 141, 193, 0.8)'
          }
        },
        scales: {
          yAxes: [
            {
              ticks: {
                padding: 10,
                fontFamily: this.FONT_FAMILY,
                beginAtZero: true
              },
              scaleLabel: {
                display: true,
                labelString: options.labelY,
                fontColor: options.lineColor || '#2A83C6',
                fontStyle: 'bold',
                fontSize: 14,
                fontFamily: this.FONT_FAMILY,
                padding: 10
              }
            }
          ],
          xAxes: [
            {
              ticks: {
                padding: 10,
                fontFamily: this.FONT_FAMILY
              }
            }
          ]
        },
        legend: {
          display: true,
          align: 'end',
          labels: {
            fontFamily: this.FONT_FAMILY,
            fontSize: 16,
            usePointStyle: true,
            boxWidth: 5
          },
          onClick: null
        },
        tooltips: {
          displayColors: false,
          xPadding: 15,
          yPadding: 15,
          titleFontSize: 14,
          titleFontFamily: this.FONT_FAMILY
        }
      }
    })
  },

  /**
   * @param {string} reportId String ID of the report, comes from data-id attr.
   * @returns {string} API URL
   */
  getApiURL: function (reportId) {
    return '/admin/reports/' + reportId + '.json' + window.location.search
  },

  /**
   * @param {object} data Data referencing information for data fetching
   * @param {Chart} chart Chart instance
   */
  updateChart: function (data, chart) {
    return fetch(this.getApiURL(data.id))
      .then(function (response) {
        return response.json()
      })
      .then(function (json) {
        chart.data.datasets[0].data = json.data
        chart.data.labels = json.labels
      })
      .finally(function () {
        chart.update()
      })
  },

  getParamValue: function (param) {
    return this.getUri().getQueryParamValue(param)
  },

  /**
   * @param {HTMLSelectElement} node DOM select not to get index of
   * @param {string} param The param from URL to search through select options
   * @returns {number} Index of option value that should be selected
   */
  getParamSelectedIndex: function (node, param) {
    var options = []
    var selectedValue = this.getParamValue(param)

    Array.prototype.forEach.call(node.options, function (el) {
      options.push(el.value)
    })

    return options.indexOf(selectedValue)
  },

  /**
   * @param {Event} e Event from HTMLElement
   * @param {string} param Query param we want to toggle
   */
  updateUrlParams: function (e, param) {
    var url = this.getUri()

    if (e.target.value === '') {
      url.deleteQueryParam(param)
    } else {
      url.replaceQueryParam(param, e.target.value)
    }

    if (param.includes('completed_at_')) {
      url.replaceQueryParam('date_range', 'custom')
    } else if (param === 'date_range') {
      var dateRange = this.getPredefinedDateRange(e.target.value)

      url.replaceQueryParam('completed_at_min', dateRange.min)
      url.replaceQueryParam('completed_at_max', dateRange.max)
    }

    window.history.pushState({}, '', url.toString())

    this.updateFilters()
    this.refreshDatePickers()
    return this.updateCharts()
  },

  /**
   * @param {HTMLSelectElement} el Select element from filter
   * @param {('next'|'prev')} dir Switch direction
   */
  selectOptionByDirection: function (el, dir) {
    if (
      (
        el.options[el.selectedIndex + 1] &&
        el.options[el.selectedIndex + 1].value === 'custom' &&
        dir === 'next'
      ) ||
      (el.selectedIndex + 1 === el.options.length && dir === 'next')
    ) {
      el.selectedIndex = 0
    } else if (el.selectedIndex === 0 && dir === 'prev') {
      el.selectedIndex = el.options.length - 2
    } else {
      if (dir === 'next') {
        el.selectedIndex++
      } else {
        el.selectedIndex--
      }
    }

    var event = document.createEvent('HTMLEvents')
    event.initEvent('change', true, false)

    return el.dispatchEvent(event)
  },

  /**
   * @param {HTMLDivElement} el Filter root node
   * @param {('prev'|'next')} dir Move direction
   * @return {HTMLLabelElement} Button to click on to move to next date range
   */
  getMoveButton: function (el, dir) {
    return el.querySelector('[data-action="' + dir + '"]')
  },

  /**
   * @param {Dayjs} min Start date
   * @param {Dayjs} max End date
   * @return {DateRange}
   */
  getDateRange: function (min, max) {
    return {
      min: min.format(this.DATE_FORMAT),
      max: max.format(this.DATE_FORMAT)
    }
  },

  /**
   * @param {DateRangeName} dateRangeName One of multiple predefined date ranges
   * @return {DateRange}
   */
  getPredefinedDateRange: function (dateRange) {
    switch (dateRange) {
      case 'last_seven_days':
        return this.getDateRange(dayjs().subtract(7, 'day'), dayjs())
      case 'this_week':
        return this.getDateRange(dayjs().startOf('week'), dayjs())
      case 'last_week':
        return this.getDateRange(
          dayjs()
            .startOf('week')
            .subtract(1, 'week'),
          dayjs()
            .startOf('week')
            .subtract(1, 'day')
        )
      case 'last_thirty_days':
        return this.getDateRange(dayjs().subtract(30, 'day'), dayjs())
      case 'this_month':
        return this.getDateRange(dayjs().startOf('month'), dayjs().endOf('month'))
      case 'last_month':
        return this.getDateRange(
          dayjs()
            .startOf('month')
            .subtract(1, 'month'),
          dayjs()
            .startOf('month')
            .subtract(1, 'day')
        )
      case 'this_year':
        return this.getDateRange(dayjs().startOf('year'), dayjs().endOf('year'))
      case 'last_year':
        return this.getDateRange(
          dayjs()
            .startOf('year')
            .subtract(1, 'year'),
          dayjs()
            .subtract(1, 'year')
            .endOf('year')
        )
      default:
        return this.getDateRange(dayjs().startOf('week'), dayjs())
    }
  },

  /**
   * @param {string} date Date string in format dd-mm-yyyy
   * @returns {Date} Date object
   */
  parseDate: function (date) {
    return new Date(
      date
        .split('-')
        .reverse()
        .join('-')
    )
  },

  /**
   * @param {HTMLElement} node - Filter HTML node
   * @returns {Date} - Date object
   */
  getMaxDate: function (node) {
    if (node.dataset.param === 'completed_at_max') {
      return this.parseDate(dayjs().format(this.DATE_FORMAT))
    } else {
      return this.parseDate(
        this.getUri().getQueryParamValue('completed_at_max') ||
          dayjs().format(this.DATE_FORMAT)
      )
    }
  },

  /**
   * @param {HTMLElement} node - Filter HTML node
   * @returns {Date} - Date object
   */
  getMinDate: function (node) {
    var self = this
    if (node.dataset.param === 'completed_at_min') {
      return self.parseDate(
        dayjs()
          .subtract(2, 'years')
          .format(this.DATE_FORMAT)
      )
    } else {
      return self.parseDate(
        self.getUri().getQueryParamValue('completed_at_min') ||
        dayjs()
          .subtract(2, 'years')
          .format(this.DATE_FORMAT)
      )
    }
  },

  /**
   * @param {HTMLElement} node - HTML node
   * @returns {boolean}
   */
  isDatePicker: function (node) {
    return node.className.split(' ').includes('datepicker')
  },

  updateSelectFilter: function (node) {
    var selectedIndexFromParams = this.getParamSelectedIndex(
      node,
      node.dataset.param
    )

    if (selectedIndexFromParams !== -1) {
      node.selectedIndex = selectedIndexFromParams
    }
  },

  /**
   * @param {HTMLInputElement} node - Filter HTML input node
   */
  updateInputFilter: function (node) {
    var value = this.getUri().getQueryParamValue(node.dataset.param)

    if (value) {
      node.value = value
    }
  },

  /**
   * @param {HTMLElement} filterWrapper - Filter parent HTML node
   * @param {HTMLSelectElement} filterNode - Filter HTML node
   */
  initSelectFilter: function (filterWrapper, filterNode) {
    var self = this
    var directions = ['prev', 'next']

    directions.forEach(function (dir) {
      var button = self.getMoveButton(filterWrapper, dir)

      button.addEventListener('click', function (e) {
        return self.selectOptionByDirection(filterNode, dir)
      })
    })

    self.updateSelectFilter(filterNode)
  },

  initDatePicker: function (node) {
    var self = this

    return $(node).datepicker({
      dateFormat: 'dd-mm-yy',
      minDate: self.getMinDate(node),
      maxDate: self.getMaxDate(node),
      onSelect: function (date, instance) {
        var event

        if (typeof window.Event === 'function') {
          event = new Event('change')
          this.dispatchEvent(event)
        } else {
          event = document.createEvent('HTMLEvents')
          event.initEvent('change', false, false)
          this.dispatchEvent(event)
        }
      }
    })
  },

  initDownloadButton: function () {
    var downloadCsvButton = document.getElementById('download-csv')

    return downloadCsvButton.addEventListener('click', function (e) {
      window.location.assign(
        window.location.pathname.replace(/(\.html)?$/, '.csv') +
          window.location.search
      )
    })
  },

  updateFilters: function () {
    var self = this
    var filterWrappers = self.getNodes('js-filter')

    Array.prototype.forEach.call(filterWrappers, function (wrapper) {
      var filterNode = wrapper.getElementsByClassName('js-filter-node')[0]

      if (filterNode.tagName === 'SELECT') {
        return self.updateSelectFilter(filterNode)
      } else if (filterNode.tagName === 'INPUT') {
        return self.updateInputFilter(filterNode)
      }
    })
  },

  clearDatePickers: function () {
    var elements = document.getElementsByClassName('datepicker')

    Array.prototype.forEach.call(elements, function (el) {
      el.value = ''
    })
  },

  refreshDatePickers: function () {
    var self = this
    var elements = document.getElementsByClassName('hasDatepicker')

    Array.prototype.forEach.call(elements, function (el) {
      $(el).datepicker('option', 'minDate', self.getMinDate(el))
      $(el).datepicker('option', 'maxDate', self.getMaxDate(el))
    })
  },

  initFilters: function () {
    var self = this
    var filterWrappers = self.getNodes('js-filter')

    Array.prototype.forEach.call(filterWrappers, function (wrapper) {
      var filterNode = wrapper.getElementsByClassName('js-filter-node')[0]

      if (filterNode.tagName === 'SELECT') {
        self.initSelectFilter(wrapper, filterNode)
      } else if (filterNode.tagName === 'INPUT') {
        if (self.isDatePicker(filterNode)) {
          self.initDatePicker(filterNode)
        }
      }

      filterNode.addEventListener('change', function (e) {
        if (
          e.target.selectedIndex && e.target.options[e.target.selectedIndex].value === 'custom'
        ) {
          var url = self.getUri()
          var $pickerEl = $('[data-param="completed_at_min"]')

          self.clearDatePickers()

          url.deleteQueryParam('completed_at_min')
          url.deleteQueryParam('completed_at_max')

          $pickerEl.datepicker('refresh')
          $pickerEl.datepicker('show')
        } else {
          return self.updateUrlParams(e, e.target.dataset.param)
        }
      })
    })
  },

  updateCharts: function () {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }

    var chartNodes = this.getNodes('reports--chart')
    var node = chartNodes[0]

    var data = this.getChartData(node)
    this.chart = this.createChart(
      node,
      {
        labels: [],
        datasets: [{ label: data.label, data: [] }]
      },
      data
    )

    this.updateChart(data, this.chart)
  }
}

document.addEventListener('DOMContentLoaded', function () {
  Spree.Reports.initDownloadButton()
  Spree.Reports.updateCharts()
  Spree.Reports.initFilters()

  window.onpopstate = function (e) {
    Spree.Reports.updateCharts()
    Spree.Reports.updateFilters()
  }
})
