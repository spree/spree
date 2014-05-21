Backend.BaseModel = Ember.Object.extend
  init: ->
    object = this
    for name, model of this.associations()
      association = this.get(name) || {}
      if association.constructor == Array
        result = $.map association, (item) ->
          item = model.create(item)
          object.associate(item)
      else
        item = model.create(association)
        object.associate(item)
        result = item

      this.set(name, result)