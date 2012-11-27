Spree::Core::Engine.routes.prepend do
  match '/admin' => 'admin/overview#index', :as => :admin

  get '/admin/analytics/sign_up' => 'admin/analytics#sign_up', :as => :admin_analytics_sign_up
  post '/admin/analytics/register' => 'admin/analytics#register', :as => :admin_analytics_register
end
