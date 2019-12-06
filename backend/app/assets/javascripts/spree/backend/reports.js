/**
 * @typedef PeriodName
 * @type {('today'|'yesterday'|'this_week'|'last_week'|'this_month'|'last_month'|'this_year'|'last_year')}
 */

/**
 * @typedef Period
 * @type {object}
 * @property {string} min - Completed At Min
 * @property {string} max - Completed At Max
 */

Spree.Reports = {
  FONT_FAMILY: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
  DATE_FORMAT: 'DD-MM-YYYY',

  /**
   * @param {string} className Class name of canvas dom nodes for charts
   * @returns {HTMLCollection} DOM nodes
   */
  getNodes: function (className) {
    return document.getElementsByClassName(className)
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
          }
        },
        scales: {
          yAxes: [{
            ticks: {
              padding: 10,
              fontFamily: this.FONT_FAMILY
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
          }],
          xAxes: [{
            ticks: {
              padding: 10,
              fontFamily: this.FONT_FAMILY
            }
          }]
        },
        legend: {
          display: true,
          align: 'end',
          labels: {
            fontFamily: this.FONT_FAMILY,
            fontSize: 16,
            usePointStyle: true,
            boxWidth: 5
          }
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
    const params = new Uri(window.location.search)

    return params.getQueryParamValue(param)
  },

  /**
   * @param {HTMLSelectElement} node DOM select not to get index of
   * @param {string} param The param from URL to search through select options
   * @returns {number} Index of option value that should be selected
   */
  getParamSelectedIndex: function (node, param) {
    const options = []
    const selectedValue = this.getParamValue(param)

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
    const url = new Uri(window.location)

    if (e.target.value === '') {
      url.deleteQueryParam(param)
    } else {
      url.replaceQueryParam(param, e.target.value)
    }

    if (param === 'period') {
      const period = this.getPredefinedPeriod(e.target.value)

      url.replaceQueryParam('completed_at_min', period.min)
      url.replaceQueryParam('completed_at_max', period.max)
    }

    if (param.includes('completed_at_')) {
      url.deleteQueryParam('period')
    }

    window.history.pushState({}, '', url.toString())

    return this.initReports()
  },

  /**
   * @param {HTMLSelectElement} el Select element from filter
   * @param {('next'|'prev')} dir Switch direction
   */
  selectOptionByDirection: function (el, dir) {
    if (el.selectedIndex + 1 === el.options.length && dir === 'next') {
      el.selectedIndex = 0
    } else if (el.selectedIndex === 0 && dir === 'prev') {
      el.selectedIndex = el.options.length - 1
    } else {
      if (dir === 'next') {
        el.selectedIndex++
      } else {
        el.selectedIndex--
      }
    }

    const event = document.createEvent('HTMLEvents')
    event.initEvent('change', true, false)

    return el.dispatchEvent(event)
  },

  /**
   * @param {HTMLDivElement} el Filter root node
   * @param {('prev'|'next')} dir Move direction
   * @return {HTMLLabelElement} Button to click on to move to next time period
   */
  getMoveButton: function (el, dir) {
    return el.querySelector('[data-action="' + dir + '"]')
  },

  /**
   * @param {Dayjs} min Start date
   * @param {Dayjs} max End date
   * @return {Period}
   */
  getPeriod: function (min, max) {
    return {
      min: min.format(this.DATE_FORMAT),
      max: max.format(this.DATE_FORMAT)
    }
  },

  /**
   * @param {PeriodName} periodName One of multiple predefined periods
   * @return {Period}
   */
  getPredefinedPeriod: function (periodName) {
    switch (periodName) {
      case 'today':
        return this.getPeriod(dayjs(), dayjs())
        break
      case 'yesterday':
        return this.getPeriod(dayjs().subtract(1, 'day'), dayjs())
        break
      case 'this_week':
        return this.getPeriod(dayjs().startOf('week'), dayjs())
        break
      case 'last_week':
        return this.getPeriod(
          dayjs().startOf('week').subtract(1, 'week'),
          dayjs().startOf('week').subtract(1, 'day')
        )
        break
      case 'this_month':
        return this.getPeriod(dayjs().startOf('month'), dayjs().endOf('month'))
        break
      case 'last_month':
        return this.getPeriod(
          dayjs().startOf('month').subtract(1, 'month'),
          dayjs().startOf('month').subtract(1, 'day')
        )
        break
      case 'this_year':
        return this.getPeriod(dayjs().startOf('year'), dayjs().endOf('year'))
        break
      case 'last_year':
        return this.getPeriod(
          dayjs().startOf('year').subtract(1, 'year'),
          dayjs().subtract(1, 'year').endOf('year')
        )
        break
      default:
        return this.getPeriod(dayjs().startOf('week'), dayjs())
    }
  },

  initFilter: function () {
    const self = this
    const filterNodes = self.getNodes('js-filter')
    const downloadCsvButton = document.getElementById('download-csv')

    Array.prototype.forEach.call(filterNodes, function (node) {
      const filterNode = node.getElementsByClassName('js-filter-node')[0]
      const isDatePicker = filterNode.className
        .split(' ')
        .includes('datepicker')

      if (filterNode.tagName === 'SELECT') {
        const directions = ['prev', 'next']

        directions.forEach(function (dir) {
          const button = self.getMoveButton(node, dir)

          button.addEventListener('click', function (e) {
            return self.selectOptionByDirection(filterNode, dir)
          })
        })

        const selectedIndexFromParams = self.getParamSelectedIndex(
          filterNode,
          filterNode.dataset.param
        )

        // Set selected value from URL param
        if (selectedIndexFromParams !== -1) {
          filterNode.selectedIndex = selectedIndexFromParams
        }
      }

      if (isDatePicker) {
        $(filterNode).datepicker({
          dateFormat: 'dd-mm-yy',
          onSelect: function() {
            let event
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
      }

      filterNode.addEventListener('change', function (e) {
        return self.updateUrlParams(e, e.target.dataset.param)
      })
    })

    downloadCsvButton.addEventListener('click', function (e) {
      window.location.assign(
        window.location.pathname.replace(/(\.html)?$/, '.csv') +
          window.location.search
      )
    })

    // Listen to browser history change and init requests
    window.onpopstate = function (e) {
      Array.prototype.forEach.call(filterNodes, function (node) {
        const filterNode = node.getElementsByClassName('.js-filter-node')[0]

        if (filterNode === 'SELECT') {
          const index = self.getParamSelectedIndex(
            filterNode,
            filterNode.dataset.param
          )

          if (index === -1) {
            filterNode.selectedIndex = 0
          } else {
            filterNode.selectedIndex = index
          }
        }
      })

      return self.initReports()
    }
  },

  initReports: function () {
    const self = this
    const chartNodes = self.getNodes('reports--chart')

    return Array.prototype.forEach.call(chartNodes, function (node) {
      const data = self.getChartData(node)
      const chart = self.createChart(
        node,
        {
          labels: [],
          datasets: [{ label: data.label, data: [] }]
        },
        data
      )

      self.updateChart(data, chart)
    })
  }
}

document.addEventListener('DOMContentLoaded', function () {
  Spree.Reports.initReports()
  Spree.Reports.initFilter()
})
