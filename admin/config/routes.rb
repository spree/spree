Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    # product catalog
    resources :properties, except: :show
    resources :option_types, except: :show do
      resources :option_values, only: [:update]
    end

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
    resources :payment_methods, except: :show
    resources :shipping_methods, except: :show
    resources :shipping_categories, except: :show
    resources :store_credit_categories
    resources :tax_rates, except: :show
    resources :tax_categories, except: :show
    resources :reimbursement_types
    resources :refund_reasons, except: :show
    resources :return_authorization_reasons, except: :show
    resources :zones
    resources :stock_locations, except: :show do
      member do
        put :mark_as_default
      end
    end

    # account management
    resources :roles, except: :show

    # developer tools
    resources :oauth_applications
    resources :webhooks_subscribers

    # errors
    get '/forbidden', to: 'errors#forbidden', as: :forbidden
  end
end
