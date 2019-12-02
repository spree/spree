/**
 * @param {string} className Class name of canvas dom nodes for charts
 * @returns {HTMLCollection} DOM nodes
 */
function getChartNodes (className) {
  return document.getElementsByClassName(className)
}

/**
 * @param {HTMLCanvasElement} node DOM node
 * @returns {object} Information to get chart data
 */
function getChartData (node) {
  return {
    type: node.dataset.type,
    label: node.dataset.label,
    id: node.dataset.id,
    labelKey: node.dataset.labelKey,
    dataKey: node.dataset.dataKey
  }
}

/**
 * @param {string} node DOM node id to hold the chart. Should be canvas.
 * @param {string} type Chart type.
 * @param {object} data Chart.js data objects holding labels and datasets to display
 * @returns {Chart}
 */
function createChart (node, type, data) {
  return new Chart(node, {
    type: type,
    data: data,
    options: {
      datasets: {
        line: {
          backgroundColor: 'rgba(71, 141, 193, 0.8)',
          borderColor: 'rgba(71, 141, 193, 1)'
        }
      },
      legend: {
        display: false
      },
      tooltips: {
        displayColors: false,
        xPadding: 15,
        yPadding: 15,
        titleFontSize: 14,
        titleFontFamily:
          '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'
      }
    }
  })
}

/**
 * @param {object} json Report data from backend api
 * @param {string} key Key to get values from
 * @returns {array} Array of values
 */
function getData (json, key) {
  return json.map(function (item) {
    return item[key]
  })
}

/**
 * @param {string} reportId String ID of the report, comes from data-id attr.
 * @returns {string} API URL
 */
function getApiURL (reportId) {
  return '/admin/reports/' + reportId + '.json' + window.location.search
}

/**
 * @param {object} data Data referencing information for data fetching
 * @param {Chart} chart Chart instance
 */
function updateChart (data, chart) {
  return fetch(getApiURL(data.id))
    .then(function (response) {
      return response.json()
    })
    .then(function (json) {
      chart.data.datasets[0].data = getData(json, data.dataKey)
      chart.data.labels = getData(json, data.labelKey)
    })
    .finally(function () {
      chart.update()
    })
}

/**
 * @param {HTMLSelectElement} node DOM select not to get index of
 * @param {string} param The param from URL to search through select options
 * @returns {number} Index of option value that should be selected
 */
function getParamSelectedIndex (node, param) {
  const options = []
  const selectedValue = new Uri(window.location.search).getQueryParamValue(param)

  Array.prototype.forEach.call(node.options, function (el) {
    options.push(el.value)
  })

  return options.indexOf(selectedValue)
}

function initFilter () {
  const groupBySelect = document.getElementById('reports-group-by')
  const selectedIndexFromParams = getParamSelectedIndex(groupBySelect, 'group_by')

  // Set selected value from URL param
  if (selectedIndexFromParams !== -1) {
    groupBySelect.selectedIndex = selectedIndexFromParams
  }

  // Change browser URL and init request when user select option
  groupBySelect.addEventListener('change', function (e) {
    const url = new Uri(window.location).replaceQueryParam(
      'group_by',
      e.target.options[e.target.selectedIndex].value
    ).toString()

    window.history.pushState({}, '', url)

    return initReports()
  })

  // Listen to browser history change and init requests
  window.onpopstate = function (e) {
    groupBySelect.selectedIndex = getParamSelectedIndex(groupBySelect, 'group_by')

    return initReports()
  }
}

function initReports () {
  const chartNodes = getChartNodes('reports--chart')

  return Array.prototype.forEach.call(chartNodes, function (node) {
    const data = getChartData(node)
    const chart = createChart(node, data.type, {
      labels: [],
      datasets: [{ label: data.label, data: [] }]
    })

    updateChart(data, chart)
  })
}

document.addEventListener('DOMContentLoaded', function () {
  initReports()
  initFilter()
})
