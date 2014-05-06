Backend.IndexRoute = Ember.Route.extend({
  beforeModel: function() {
    this.transitionTo('orders');
  }
})