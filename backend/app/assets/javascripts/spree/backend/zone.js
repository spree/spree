document.addEventListener('DOMContentLoaded', function () {
  var typeRadioButtons = "input[name='zone[kind]']"

  if (document.querySelector(typeRadioButtons)) {
    var radioSelected = document.querySelector(typeRadioButtons + ':checked').value
    var shownZoneMembers = radioSelected + '_members'
    var zoneMembersContainer = 'div[data-hook=member]'
    var activeInput = 'zone_' + radioSelected + '_ids_field'

    toggleTypes(activeInput, zoneMembersContainer, shownZoneMembers)

    document.querySelectorAll(typeRadioButtons).forEach(function (elem) {
      elem.addEventListener('change', function (event) {
        var item = event.target.value
        var toggledTypeMemebers = item + '_members'
        var toggledaActiveInput = 'zone_' + item + '_ids_field'

        toggleTypes(toggledaActiveInput, zoneMembersContainer, toggledTypeMemebers)
      })
    })
  }

  function toggleTypes (activeInput, membersContainer, shownType) {
    document.getElementById('typeMembers')
      .querySelectorAll('select, input').forEach(function (element) {
        element.disabled = true
      })

    document.getElementById(activeInput)
      .querySelectorAll('select, input').forEach(function (element) {
        element.disabled = false
      })

    document.querySelectorAll(membersContainer).forEach(function (element) {
      element.style.display = 'none'
    })

    document.getElementById(shownType).style.display = 'block'
  }
})
