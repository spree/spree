Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    resources :stores, only: [:new, :create], controller: 'multi_store/stores'
    resources :custom_domains, except: :show
  end
end
