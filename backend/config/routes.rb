Spree::Core::Engine.add_routes do
  namespace :admin do
    post '/addresses/shipment/:shipment_id', to: "addresses#create_shipment", as: :shipment_address

    get '/search/users', to: "search#users", as: :search_users
    get '/search/products', to: "search#products", as: :search_products

    resources :promotions do
      resources :promotion_rules
      resources :promotion_actions
    end

    resources :promotion_categories, except: [:show]

    resources :zones

    resources :countries do
      resources :states
    end
    resources :states
    resources :tax_categories

    resources :products do
      resources :product_properties do
        collection do
          post :update_positions
        end
      end
      resources :images do
        collection do
          post :update_positions
        end
      end
      member do
        get :clone
        get :stock
      end
      resources :variants do
        collection do
          post :update_positions
        end
      end
      resources :variants_including_master, only: [:update]
    end

    get '/variants/search', to: "variants#search", as: :search_variants

    resources :option_types do
      collection do
        post :update_positions
        post :update_values_positions
      end
    end

    delete '/option_values/:id', to: "option_values#destroy", as: :option_value

    resources :properties do
      collection do
        get :filtered
      end
    end

    delete '/product_properties/:id', to: "product_properties#destroy", as: :product_property

    resources :prototypes do
      member do
        get :select
      end

      collection do
        get :available
      end
    end

    resources :orders, except: [:show] do
      member do
        get :shipments
        get :cart
        post :resend
        get :open_adjustments
        get :close_adjustments
        put :approve
        put :cancel
        put :resume
        get :risky_order_info
      end

      resources :state_changes, only: [:index]

      resource :customer, controller: "orders/customer_details"
      resources :customer_returns, only: [:index, :new, :edit, :create, :update] do
        member do
          put :refund
        end
      end

      resources :adjustments
      resources :line_items
      resources :return_authorizations do
        member do
          put :fire
        end
      end
      resources :payments do
        member do
          put :fire
        end

        resources :log_entries
        resources :refunds, only: [:new, :create, :edit, :update]
      end

      get :promotions, to: "promotions#order_promotions", as: :promotions
      post :apply_promotion, to: "promotions#apply_to_order", as: :apply_promotion
      post :delete_promotion, to: "promotions#delete_from_order", as: :delete_promotion

      resources :reimbursements do
        member do
          post :perform
        end
      end
    end
    get '/orders/risky', to: "orders#risky", as: :risky_orders

    resource :general_settings do
      collection do
        post :dismiss_alert
        post :clear_cache
      end
    end

    resources :return_items, only: [:update]

    resources :taxonomies do
      collection do
        post :update_positions
      end
      member do
        get :get_children
      end
      resources :taxons
    end

    resources :taxons, only: [:index, :show] do
      collection do
        get :search
      end
    end

    resources :reports, only: [:index] do
      collection do
        get :sales_total
        post :sales_total
      end
    end

    resources :reimbursement_types, only: [:index]
    resources :refund_reasons, except: [:show, :destroy]
    resources :return_authorization_reasons, except: [:show, :destroy]

    resources :shipping_methods
    resources :shipping_categories
    resources :stock_transfers, only: [:index, :show, :new, :create]
    resources :stock_locations do
      resources :stock_movements, except: [:edit, :update, :destroy]
      collection do
        post :transfer_stock
      end
    end

    resources :stock_items, only: [:create, :update, :destroy]
    resources :tax_rates

    resources :trackers
    resources :payment_methods
    resources :roles

    get '/return_index/return_authorizations', to: "return_index#return_authorizations", as: :return_authorizations_index
    get '/return_index/customer_returns', to: "return_index#customer_returns", as: :customer_returns_index

    resources :users do
      member do
        get :orders
        get :items
        get :addresses
        put :addresses
        get :api_access
        get :roles
      end
    end
  end

  get '/admin', to: 'admin/root#index', as: :admin
end
