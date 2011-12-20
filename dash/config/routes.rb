Spree::Core::Engine.routes.prepend do
  match '/admin' => 'admin/overview#index', :as => :admin
  match '/admin/dash_preferences' => 'admin/overview#preferences', :as => :admin_dash_preferences
end
