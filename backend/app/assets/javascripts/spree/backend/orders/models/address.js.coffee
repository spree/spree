Backend.Address = Ember.Object.extend
  # TODO: Is there a better way of doing this?
  # We only want these parameters to be passed back to the API
  # The normal address contains things like country and state information, which the API does not accept
  formParams: (->
    fields = [
      'firstname'
      'lastname'
      'address1'
      'address2'
      'city'
      'country_id'
      'state_id'
      'zipcode'
      'phone'
    ]

    address = this
    params = {}
    fields.forEach (field) ->
      params[field] = address.get(field)
    params
  ).property('formParams').volatile()