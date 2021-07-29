/**
  populateSelectOptionsFromApi(params)

  Allows you to easily fetch data from API (Platfrom v2)
  and populate an empty <select> with <option> tags,
  including a selected <option> tag.

  ## EXAMPLE USE CASE called from ERB view file:

  populateSelectOptionsFromApi({
    targetElement: '#mySelectElement',
    apiUrl: Spree.routes.taxons_api_v2,
    returnAttribute: 'pretty_name',

    <% if @menu_item.linked_resource_id %>
      selectedOption: <%= @menu_item.linked_resource_id %>
    <% end %>
  })
**/

// eslint-disable-next-line no-unused-vars
const populateSelectOptionsFromApi = function(params) {
  createRequest(params, updateSelectSuccess, updateSelectError)
}

const handleErrors = function(response) {
  if (!response.ok) throw new Error((response.status + ': ' + response.statusText))

  return response.json()
}

const createRequest = function(params, succeed, fail) {
  const targetElement = params.targetElement
  const apiUrl = params.apiUrl
  const returnAttribute = params.returnAttribute
  const selectedOption = params.selectedOption
  const selectEl = document.querySelector(targetElement)

  fetch(apiUrl, { headers: Spree.apiV2Authentication() })
    .then((response) => handleErrors(response))
    .then((json) => succeed(json.data, returnAttribute, selectEl, selectedOption))
    .catch((error) => fail(error, selectEl))
}

const updateSelectSuccess = function(parsedData, returnAttribute, selectEl, selectedOption) {
  parsedData.forEach((object) => {
    const optionEl = document.createElement('option')
    optionEl.value = object.id
    optionEl.innerHTML = object.attributes[returnAttribute]

    if (parseInt(selectedOption, 10) === parseInt(object.id, 10)) optionEl.selected = true

    selectEl.appendChild(optionEl)
  })
}

const updateSelectError = function(error, selectEl) {
  selectEl.disabled = true

  console.log(error)
}
