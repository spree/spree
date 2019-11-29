/**
 * @param {string} className Class name of canvas dom nodes for charts
 * @returns {HTMLCollection} DOM nodes
 */
function getChartNodes (className) {
  return document.getElementsByClassName(className)
}

/**
 * @param {HTMLCanvasElement} node DOM node
 */
function getChartData (node) {
  return {
    type: node.dataset.type,
    datasets: JSON.parse(node.dataset.datasets),
    labels: JSON.parse(node.dataset.labels)
  }
}

/**
 * @param {string} node DOM node id to hold the chart. Should be canvas.
 * @param {string} type Chart type.
 * @param {object} data Chart.js data objects holding labels and datasets to display
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

function initReports () {
  const nodes = getChartNodes('reports--chart')

  return Array.prototype.forEach.call(nodes, function (node) {
    const data = getChartData(node)
    createChart(node, data.type, {labels: data.labels, datasets: data.datasets})
  })
}

document.addEventListener('DOMContentLoaded', function () {
  initReports()
})
