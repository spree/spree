/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */

//
// Shows the progress bar on fech requests
const showProgressIndicator = () => {
  const progressBar = document.querySelector('#progress')
  progressBar.classList.add('d-block')
  animateCSS('#progress', 'fadeIn', 'faster')
}

//
// Hides the progress bar on fech requests
const hideProgressIndicator = () => {
  const progressBar = document.querySelector('#progress')

  animateCSS('#progress', 'fadeOut', 'fast')

  progressBar.addEventListener('animationend', () => {
    progressBar.classList.remove('d-block')
  })
}

//
// Handles the fetch request response.
// If the response has content it is returned, else if the response is a 204 no-content,
// the resolved text is returned.
const spreeHandleFetchRequestResponse = function(response) {
  hideProgressIndicator()

  if (response.status === 204) {
    return response.text()
  } else {
    return response.json()
  }
}

//
// Handles fech request errors by triggering the appropriate flash alert type and displaying
// the response message.
const spreeHandleFetchRequestError = function(data) {
  if (data.error != null) {
    show_flash('error', data.error)
  } else if (data.message != null) {
    show_flash('success', data.message)
  } else if (data.exception != null) {
    show_flash('info', data.exception)
  } else if (data.detail != null) {
    show_flash('info', data.detail)
  }
}

//
// Reloads the window.
const spreeWindowReload = function() {
  window.location.reload()
}

//
// SPREE FECTCH REQUEST
// Pass a data hash containing your fetch request details and settings, you can also send a second optional
// argument, this second argument is your success response handeler, and lastly a third argument that carries
// through a target element to the response method if needed, the second and third arguments are optional.
// When using spreeFetchRequest() the loading... progress bar, flash notice and errors are all handled for you.
//
// EXAMPLE SENDING A POST REQUEST TO CREATE A NEW SHIPMENT:
//    const data = {
//      order_id: 'H8213728798',
//      variant_id: 2,
//      quantity: 4,
//      stock_location_id: 1
//    }
//
//    const requestData = {
//      // request details
//      uri: Spree.routes.shipments_api_v2,
//      method: 'POST',
//      dataBody: data,
//
//   // Optional Settings
//   // disableProgressIndicator: true,   Allows you to disable the progress loader bar if needed.
//   // formatDataBody: false             If you have pre-formatted data, pass this option to stop the function performing the default stringify.
//    }
//    spreeFetchRequest(requestData, someCallbackFunction, this)
//
const spreeFetchRequest = function(requstData, success = null, target = null) {
  if (!requstData.disableProgressIndicator === true) showProgressIndicator()

  let platformApiv2dataBody

  const platformApiv2Uri = requstData.uri || null
  const platformApiv2method = requstData.method || 'GET'

  if (requstData.formatDataBody === false) {
    platformApiv2dataBody = requstData.dataBody
  } else {
    platformApiv2dataBody = JSON.stringify(requstData.dataBody) || null
  }

  if (platformApiv2Uri == null) return

  fetch(platformApiv2Uri, {
    method: platformApiv2method,
    headers: Spree.apiV2Authentication(),
    body: platformApiv2dataBody
  })
    .then((response) => spreeHandleFetchRequestResponse(response)
      .then((data) => {
        if (response.ok) {
          if (success != null) success(data, target)
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}
