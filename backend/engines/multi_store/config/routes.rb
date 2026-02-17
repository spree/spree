Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    resources :stores, only: [:new, :create], controller: 'multi_store/stores' do
      resources :role_users, only: [:destroy]
      resources :links, controller: 'page_links', only: [:create]
    end
    resources :custom_domains, except: :show
  end
end
