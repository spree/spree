ActionController::Routing::Routes.draw do |map|
  map.resources :projects

  map.resources :people
  
  map.resources :dudes, :controller => "users"

  map.resources :users do |user|
    user.resources :photos, :name_prefix => "user_"
  end

  map.resources :somethings

  map.resources :photos do |photo|
    photo.resources :tags, :name_prefix => "photo_"
  end
  
  map.resources :tags
  
  map.namespace :cms do |cms|
    cms.resources :products, :has_many => :options
  end

  map.resources :posts do |post|
    post.resources :comments, :name_prefix => "post_"
  end
  
  map.resources :comments

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

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
