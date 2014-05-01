Backend.UserPicker = Ember.TextField.extend
  didInsertElement: ->
    view = this
    users_api = Spree.pathFor('api/users')

    $("#order_user_id").select2
      placeholder: Spree.translations.choose_a_customer
      initSelection: (element, callback) ->
        $.get "#{users_api}/#{element.val()}", (data) ->
          callback(data)
      ajax:
        url: users_api
        datatype: 'json'
        data: (term, page) ->
          q: 
            email_cont: term
        results: (data, page) ->
          results: data.users
      dropdownCssClass: 'customer_search'
      formatResult: (customer) ->
        Ember.TEMPLATES['users/autocomplete.raw']
          customer: customer,
          bill_address: customer.bill_address,
          ship_address: customer.ship_address
          translations:
            bill_address: I18n.t('order.bill_address')
            ship_address: I18n.t('order.ship_address')
      formatSelection: (customer) ->
        view.sendAction('action', customer)
        customer.email
