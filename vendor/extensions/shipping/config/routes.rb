map.namespace :admin do |admin|
  admin.resources :shipments
  admin.resources :shipping_methods
  admin.resources :shipping_categories  
  admin.resources :orders, :has_many => :shipments
end  
map.resources :shipments
map.resources :orders, :has_many => :shipments, :member => {:fatal_shipping => :get}
