ActionController::Routing::Routes.draw do |map|
  map.resources :tax_categories

  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  map.root :controller => "products", :action => "index"
  # login mappings should appear before all others
  map.connect '/login', :controller => 'account', :action => 'login'
  map.connect '/logout', :controller => 'account', :action => 'logout'
  map.connect '/signup', :controller => 'account', :action => 'signup'
  map.connect '/admin', :controller => 'admin/overview', :action => 'index'  

  map.resources :countries, :has_many => :states, :actions => [:index]
  map.resources :states, :actions => [:index]
  
  map.resources :users
  map.resources :products, :member => {:change_image => :post}
  
  map.namespace :admin do |admin|
    admin.resources :zones
    admin.resources :countries, :has_many => :states
    admin.resources :states
    admin.resources :tax_categories
  end
  
  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'

end