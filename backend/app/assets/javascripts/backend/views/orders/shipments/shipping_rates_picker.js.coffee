Backend.ShippingRatesPicker = Ember.Select.extend
  didInsertElement: ->
    $("##{this.elementId}").select2
      dropdownCssClass: 'fullwidth'