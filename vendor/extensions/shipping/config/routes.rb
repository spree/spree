map.namespace :admin do |admin|
  admin.resources :shipments
  admin.resources :shipping_methods
  admin.resources :shipping_categories  
  admin.resources :orders, :has_many => :shipments
end  
#map.resources :shipments, :member => {:shipping_method => :any}
map.resources :orders, :member => {:fatal_shipping => :get} do |order|
  order.resources :shipments, :member => {:shipping_method => :get}
end