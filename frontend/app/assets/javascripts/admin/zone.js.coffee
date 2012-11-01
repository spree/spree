$ ->
  if ($ '#country_based').is(':checked')
    show_country()
  else
    show_state()
  ($ '#country_based').click ->
    show_country()

  ($ '#state_based').click ->
    show_state()


show_country = ->
  ($ '#state_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#state_members').hide()
  ($ '#zone_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#zone_members').hide()
  ($ '#country_members :input').each ->
    ($ this).prop 'disabled', false

  ($ '#country_members').show()

show_state = ->
  ($ '#country_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#country_members').hide()
  ($ '#zone_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#zone_members').hide()
  ($ '#state_members :input').each ->
    ($ this).prop 'disabled', false

  ($ '#state_members').show()