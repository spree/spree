/* eslint-disable no-unused-vars */
function populateSelectOptionsFromApi(params) {
  const targetElement = params.targetElement
  const apiUrl = params.apiUrl
  const returnAttribute = params.returnAttribute
  const selectedOption = params.selectedOption

  fetch(apiUrl, {
    headers: Spree.apiV2Authentication()
  }).then((response) => {
    switch (response.status) {
      case 200:
        response.json()
          .then((json) => {
            const object = json.data
            populateSelect(object, returnAttribute, targetElement, selectedOption)
          })
        break
    }
  })
}

function populateSelect (object, returnAttribute, targetElement, selectedOption) {
  const resourceSelect = document.querySelector(targetElement)

  object.forEach((item) => {
    const oppt = document.createElement('option');
    oppt.value = item.id;
    oppt.innerHTML = item.attributes[returnAttribute];

    if (parseInt(selectedOption, 10) === parseInt(item.id, 10)) {
      oppt.selected = true;
    }
    resourceSelect.appendChild(oppt)
  })
}
