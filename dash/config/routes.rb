Rails.application.routes.draw do
  match '/admin' => 'admin/overview#index', :as => :admin
  match '/admin/overview/get_report_data' => 'admin/overview#get_report_data'
end
