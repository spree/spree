 Backend.Store = DS.Store.extend
  cache: {}
  find: (model, id) ->
    this.cache[model] = this.cache[model] || new Ember.Map
    if this.cache[model].has(id)
      this.cache[model].get(id)
    else
      object = this.modelFor(model).find(id)
      this.cache[model].set(id, object)
      object

