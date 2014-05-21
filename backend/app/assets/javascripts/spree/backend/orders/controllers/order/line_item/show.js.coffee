Backend.OrderLineItemShowController = Ember.ObjectController.extend
  needs: ['order']
  order: Ember.computed.alias("controllers.order")
  
  image: (->
    if image = @get('variant').images[0]
      image.mini_url
    else
      '/assets/noimage/mini.png'
  ).property('image')

  canUpdate: Em.computed.oneWay('order.permissions.can_update')
  
  actions:
    edit: ->
      @set 'editing', true
    save: ->
      @set 'editing', false
      @get('model').update()
    cancel: ->
      @set 'editing', false
    delete: ->
      if confirm(Spree.translations.are_you_sure_delete)
        @get('model').destroy()