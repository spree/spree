Spree::Core::Engine.routes.draw do
  get '/admin' => 'admin/overview#index', :as => :admin_overview

  get '/admin/analytics/register' => 'admin/analytics#register', :as => :admin_analytics_register
  get '/admin/analytics/sync' => 'admin/analytics#sync', :as => :admin_analytics_sync

  get '/jirafe' => 'admin/analytics#edit', :as => :admin_analytics
  put '/jirafe' => 'admin/analytics#update', :as => :update_admin_analytics
end
