/**
  populateSelectOptionsFromApi()

  Allows you to easily fetch data from API (Platfrom v2)
  and populate an empty Select2 with options, including a pre selected option.

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
};

const createRequest = function(params, succeed, fail, init) {
  const targetElement = params.targetElement
  const apiUrl = params.apiUrl
  const returnAttribute = params.returnAttribute
  const selectedOption = params.selectedOption

  fetch(apiUrl, { headers: Spree.apiV2Authentication() })
    .then((response) => handleErrors(response))
    .then((json) => succeed(json.data, returnAttribute, targetElement, selectedOption))
    .catch((error) => fail(error, targetElement));
};

const handleErrors = function(response) {
  if (!response.ok) {
    throw new Error((response.status + ': ' + response.statusText));
  }
  return response.json();
}

const updateSelectSuccess = function(parsedData, returnAttribute, targetElement, selectedOption) {
  const selectEl = document.querySelector(targetElement)

  parsedData.forEach((item) => {
    const oppt = document.createElement('option');
    oppt.value = item.id;
    oppt.innerHTML = item.attributes[returnAttribute];

    if (parseInt(selectedOption, 10) === parseInt(item.id, 10)) {
      oppt.selected = true;
    }
    selectEl.appendChild(oppt)
  })
}

const updateSelectError = function(error, targetElement) {
  const selectEl = document.querySelector(targetElement)
  selectEl.disabled = true

  console.log(error)
};
