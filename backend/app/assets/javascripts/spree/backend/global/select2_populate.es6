/**
  populateSelectOptionsFromApi(params)
  Allows you to easily fetch data from API (Platfrom v2) and populate an empty <select> with <option> tags, including a selected <option> tag.

  ## EXAMPLE A
  # Populating a list of all taxons including a selected item

  populateSelectOptionsFromApi({
    targetElement: '#mySelectElement',
    apiUrl: Spree.routes.taxons_api_v2,
    returnAttribute: 'pretty_name',

    <% if @menu_item.linked_resource_id %>
      selectedOption: <%= @menu_item.linked_resource_id %>
    <% end %>
  })

  ## EXAMPLE B
  # Populating a single selected item using filter and returning an attribute other than the ID

  <% if resource.link_one.present? %>
    <script>
      populateSelectOptionsFromApi({
        targetElement: "#<%= save_to %>Select2",
        apiUrl: Spree.routes.taxons_api_v2 + "?filter[permalink_matches]=<%= resource.send(save_to) %>",
        returnValueFromAttributes: 'permalink',
        returnOptionText: 'pretty_name',

        <% if resource.send(save_to) %>
          selectedOption: "<%= resource.send(save_to) %>"
        <% end %>
      })
    </script>
  <% end %>
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
  const returnOptionText = params.returnOptionText
  const returnValueFromAttributes = params.returnValueFromAttributes || null
  const selectedOption = params.selectedOption
  const selectEl = document.querySelector(targetElement)

  fetch(apiUrl, { headers: Spree.apiV2Authentication() })
    .then((response) => handleErrors(response))
    .then((json) => succeed(json.data, returnValueFromAttributes, returnOptionText, selectEl, selectedOption))
    .catch((error) => fail(error, selectEl))
}

const updateSelectSuccess = function(parsedData, returnValueFromAttributes, returnOptionText, selectEl, selectedOption) {
  const selectedOpt = selectEl.querySelector('option[selected]')

  parsedData.forEach((object) => {
    const optionEl = document.createElement('option')

    if (returnValueFromAttributes == null) {
      optionEl.value = object.id
      if (parseInt(selectedOption, 10) === parseInt(object.id, 10)) optionEl.selected = true
    } else {
      optionEl.value = object.attributes[returnValueFromAttributes]
      if (selectedOpt.value === object.attributes[returnValueFromAttributes]) {
        selectedOpt.remove()

        optionEl.setAttribute('selected', 'selected')
      }
    }

    optionEl.innerHTML = object.attributes[returnOptionText]
    selectEl.appendChild(optionEl)
  })
}

const updateSelectError = function(error, selectEl) {
  console.log(error)
}
