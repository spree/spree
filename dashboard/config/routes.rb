Spree::Application.routes.draw do |map|
  match '/admin' => 'admin/overview#index', :as => :admin
end