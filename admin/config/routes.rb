Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    # media library
    resources :assets, only: [:create, :edit, :update, :destroy] do
      collection do
        delete :bulk_destroy
      end
    end
  end
end
