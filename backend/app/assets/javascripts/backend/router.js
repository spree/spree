// For more information see: http://emberjs.com/guides/routing/

Backend.Router.map(function() {
  this.resource('orders', { path: '/admin/orders'});
  this.resource('order', { path: '/admin/orders/:order_number' }, function() {
    this.route('state', { path: '/:state' });
  });
});

Backend.Router.reopen({
  location: 'history'
});
