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
 * @param {object} data Data referencing information for data fetching
 * @param {Chart} chart Chart instance
 */
function updateChart (data, chart) {
  return fetch(`/admin/reports/${data.id}.json`)
    .then(function (response) {
      return response.json()
    })
    .then(function (json) {
      chart.data.datasets[0].data = getData(json, data.dataKey)
      chart.data.labels = getData(json, data.labelKey)
    }).finally(function () {
      chart.update()
    })
}

function initReports () {
  const nodes = getChartNodes('reports--chart')

  return Array.prototype.forEach.call(nodes, function (node) {
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
})
