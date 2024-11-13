Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    # media library
    resources :assets, only: [:create, :edit, :update, :destroy] do
      collection do
        delete :bulk_destroy
      end
    end

    # audit log
    resources :exports, only: %i[new create show index]

    # profile settings
    resource :profile, controller: 'profile', only: %i[edit update]

    # store settings
    resources :stock_locations, except: [:show] do
      member do
        put :mark_as_default
      end
    end
  end
end
