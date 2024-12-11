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

    # products
    resources :products do
      collection do
        get :select_options, defaults: { format: :json }
        post :search
        get :bulk_modal
        put :bulk_status_update
        put :bulk_add_to_taxons
        put :bulk_remove_from_taxons
        put :bulk_add_tags
        put :bulk_remove_tags
      end

      member do
        post :clone
      end

      resources :variants, only: [:edit, :update, :destroy]
      resources :digitals, only: [:index, :create, :destroy]
    end

    # stock
    resources :stock_items, only: [:index, :update, :destroy]
    resources :stock_transfers, except: [:edit, :update]

    # taxonomies and taxons
    resources :taxonomies do
      resources :taxons do
        member do
          put :reposition
        end
      end
    end

    resources :taxons, except: [:show] do |_taxon|
      resources :classifications, only: %i[index new create update destroy]
    end

    get '/taxons/select_options' => 'taxons#select_options', as: :taxons_select_options, defaults: { format: :json }

    # errors
    get '/forbidden', to: 'errors#forbidden', as: :forbidden
  end
end
