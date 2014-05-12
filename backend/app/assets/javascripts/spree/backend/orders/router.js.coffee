Backend.Router.map ->
  this.resource 'orders', path: '/admin/orders' 
  this.resource 'order', path: '/admin/orders/:order_number', -> 
    this.resource 'payments', ->
      this.route 'new'

Backend.Router.reopen
  location: 'history'
