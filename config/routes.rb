ActionController::Routing::Routes.draw do |map|
  # Loads all extension routes in the order they are specified.
  map.load_extension_routes

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
  #map.connect ':controller/service.wsdl', :action => 'wsdl'

  # map.connect '/locale/:new_locale', :controller => 'locale', :action => 'set_session_locale'

  map.root :controller => "products", :action => "index"

  map.resource :user_session, :member => {:login_bar => :get}
  map.resource :account, :controller => "users"
  map.resources :password_resets
  
  # login mappings should appear before all others
  map.login '/login', :controller => 'user_sessions', :action => 'new'
  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.admin '/admin', :controller => 'admin/overview', :action => 'index'  
  
  map.resources :tax_categories
  map.resources :countries, :has_many => :states, :only => :index
  map.resources :states, :only => :index
  map.resources :users
  map.resources :products, :member => {:change_image => :post}
  map.resources :orders, :member => {:address_info => :get}, :has_many => [:line_items, :creditcards, :creditcard_payments], :has_one => :checkout
  map.resources :orders, :member => {:fatal_shipping => :get} do |order|
    order.resources :shipments, :member => {:shipping_method => :get}
  end
  #map.resources :shipments, :member => {:shipping_method => :any}

  # route globbing for pretty nested taxon and product paths
  map.taxons_with_product '/t/*taxon_path/p/:id', :controller => 'products', :action => 'show'
  map.nested_taxons '/t/*id', :controller => 'taxons', :action => 'show'
  
  #moved old taxons route to after nested_taxons so nested_taxons will be default route
  #this route maybe removed in the near future (no longer used by core)
  map.resources :taxons
  
  map.namespace :admin do |admin|          
    admin.resources :coupons
    admin.resources :zones
    admin.resources :users
    admin.resources :countries, :has_many => :states
    admin.resources :states
    admin.resources :tax_categories
    admin.resources :configurations
    admin.resources :products, :has_many => [:product_properties, :images] do |product|
			product.resources :variants 
      product.resources :option_types, :member => {:select => :get, :remove => :get}, :collection => {:available => :get, :selected => :get}
      product.resources :taxons, :member => {:select => :post, :remove => :post}, :collection => {:available => :post, :selected => :get}
    end
    admin.resources :option_types
    admin.resources :properties, :collection => {:filtered => :get}
    admin.resources :prototypes, :member => {:select => :post}, :collection => {:available => :get}
    admin.resource :mail_settings
    admin.resource :inventory_settings
    admin.resources :google_analytics
    admin.resources :orders, :has_many => :shipments
    admin.resources :orders, :has_many => [:payments, :creditcards], :member => {:fire => :put, :resend => :post}
    admin.resources :orders do |order|
      order.resources :creditcard_payments, :member => {:capture => :get}
    end
    admin.resource :general_settings
    admin.resources :taxonomies do |taxonomy|
      taxonomy.resources :taxons
    end 
    admin.resources :reports, :only => [:index, :show], :collection => {:sales_total => :get}

    admin.resources :shipments
    admin.resources :shipping_methods
    admin.resources :shipping_categories
    admin.resources :shipping_rates
    admin.resources :tax_rates
    admin.resource  :tax_settings    
    admin.resources :calculators
  end                   

  
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'  
  
  # a catchall route for "static" content
  map.connect '*path', :controller => 'content', :action => 'show'

end
