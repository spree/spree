Spree.Reports = {
  FONT_FAMILY: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',

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
    return fetch(Spree.Reports.getApiURL(data.id))
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
    const selectedValue = Spree.Reports.getParamValue(param)

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

    window.history.pushState({}, '', url.toString())

    return Spree.Reports.initReports()
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

  initFilter: function () {
    const filterNodes = Spree.Reports.getNodes('js-filter-select')
    const downloadCsvButton = document.getElementById('download-csv')

    Array.prototype.forEach.call(filterNodes, function (node) {
      const select = node.querySelector('select')
      const directions = ['prev', 'next']

      directions.forEach(function (dir) {
        const button = Spree.Reports.getMoveButton(node, dir)

        button.addEventListener('click', function (e) {
          return Spree.Reports.selectOptionByDirection(select, dir)
        })
      })

      select.addEventListener('change', function (e) {
        return Spree.Reports.updateUrlParams(e, e.target.dataset.param)
      })

      const selectedIndexFromParams = Spree.Reports.getParamSelectedIndex(
        select,
        select.dataset.param
      )

      // Set selected value from URL param
      if (selectedIndexFromParams !== -1) {
        select.selectedIndex = selectedIndexFromParams
      }
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
        const select = node.querySelector('select')
        const index = Spree.Reports.getParamSelectedIndex(select, select.dataset.param)

        if (index === -1) {
          select.selectedIndex = 0
        } else {
          select.selectedIndex = index
        }
      })

      return Spree.Reports.initReports()
    }
  },

  initReports: function () {
    const chartNodes = Spree.Reports.getNodes('reports--chart')

    return Array.prototype.forEach.call(chartNodes, function (node) {
      const data = Spree.Reports.getChartData(node)
      const chart = Spree.Reports.createChart(
        node,
        {
          labels: [],
          datasets: [{ label: data.label, data: [] }]
        },
        data
      )

      Spree.Reports.updateChart(data, chart)
    })
  }
}

document.addEventListener('DOMContentLoaded', function () {
  Spree.Reports.initReports()
  Spree.Reports.initFilter()
})
