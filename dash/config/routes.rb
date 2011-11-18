Spree::Core::Engine.routes.prepend do
  match '/admin' => 'admin/overview#index', :as => :admin
  match '/admin/overview/get_report_data' => 'admin/overview#get_report_data'
end
