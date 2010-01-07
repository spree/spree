map.namespace :admin do |admin|
  admin.resources :users, :member => {:generate_api_key => :put, :clear_api_key => :put}
end
map.namespace :api do |api|
  api.resources :shipments, :except => [:new,:edit], :member => {:event => :put}
  api.resources :orders, :except => [:new,:edit], :member => {:event => :put} do |orders|
    orders.resources :shipments, :except => [:new,:edit]
    orders.resources :line_items, :except => [:new,:edit]
  end
end
