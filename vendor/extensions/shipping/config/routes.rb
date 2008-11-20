map.namespace :admin do |admin|
  admin.resources :shipping_methods
  admin.resources :shipping_categories  
end  
map.resources :shipments
map.resources :orders, :has_many => :shipments, :member => {:fatal_shipping => :get}
