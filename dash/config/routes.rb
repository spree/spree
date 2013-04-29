Spree::Core::Engine.routes.draw do
  match '/admin' => 'admin/overview#index', :as => :admin

  get '/admin/analytics/register' => 'admin/analytics#register', :as => :admin_analytics_register
  get '/admin/analytics/sync' => 'admin/analytics#sync', :as => :admin_analytics_sync

  get '/jirafe' => 'admin/analytics#edit', :as => :admin_analytics
  put '/jirafe' => 'admin/analytics#update', :as => :admin_analytics
end
