Backend.OrdersAddressesFormView = Ember.View.extend
  didInsertElement: ->
    @initCountryPicker()
    @didChangeCountry()

  initCountryPicker: ->
    el = $("##{this.elementId}")
    countries_api = Spree.pathFor('api/countries')
    el.find(".country_select").select2
      initSelection: (element, callback) ->
        $.ajax
          url: countries_api + "/#{element.val()}"
        .done (response) ->
          callback(response)
      ajax:
        url: countries_api
        data: (term, page) ->
          q:
            name_cont: term
        results: (data, page) ->
          results: data["countries"]
      formatResult: (country) ->
        country.name
      formatSelection: (country) ->
        country.name
      containerCssClass: 'fullwidth'

  didChangeCountry: (->
    if this.state == 'inDOM'
      el = $("##{this.elementId}")

      country_id = el.find("input.country_select").val()
      if country_id
        states_api = Spree.pathFor("api/countries/#{country_id}/states")
      else
        states_api = Spree.pathFor("api/states")

      $.get states_api, (data) ->
        states = data.states
        state_select = el.find("input.state_select")
        if states.length > 0
          state_select.select2
            data: states
            formatResult: (state) ->
              state.name
            formatSelection: (state) ->
              state.name
            initSelection: (element, callback) ->
              $.ajax
                url: states_api + "/#{element.val()}"
              .done (response) ->
                callback(response)
            containerCssClass: 'fullwidth'
  ).observes('controller.model.country_id')