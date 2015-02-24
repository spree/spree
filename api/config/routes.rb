Spree::Core::Engine.add_routes do
  namespace :admin do
    resources :users do
      put :generate_api_key,
          :clear_api_key,
          on: :member
    end
  end

  namespace :api, defaults: { format: 'json' } do
    resources :properties, :stores, :zones

    resources :promotions, only: :show
    resources :taxons, :option_values, only: :index
    resources :inventory_units, only: [:show, :update]
    resources :stock_items, only: [:index, :update, :destroy]
    resources :states, only: [:index, :show]

    resources :products do
      resources :images, :variants, :product_properties
    end

    concern :order_routes do
      put :cancel,
          :empty,
          :apply_coupon_code,
          on: :member

      resources :line_items
      resources :payments do
        put :authorize,
            :capture,
            :purchase,
            :void,
            :credit,
            on: :member
      end

      resources :addresses, only: [:show, :update]

      resources :return_authorizations do
        put :add,
            :cancel,
            :receive,
            on: :member
      end
    end

    resources :checkouts, only: [:update], concerns: :order_routes do
      put :next,
          :advance,
          on: :member
    end

    resources :variants do
      resources :images
    end

    resources :option_types do
      resources :option_values
    end

    get '/orders/mine', to: 'orders#mine', as: 'my_orders'
    get "/orders/current", to: "orders#current", as: "current_order"

    resources :orders, concerns: :order_routes

    resources :countries, only: [:index, :show] do
      resources :states, only: [:index, :show]
    end

    resources :shipments, only: [:create, :update] do
      put :ready, :ship, :add, :remove, on: :member

      collection do
        post 'transfer_to_location'
        post 'transfer_to_shipment'
        get :mine
      end
    end

    resources :taxonomies do
      get :jstree, on: :member
      resources :taxons do
        get :jstree, on: :member
      end
    end

    resources :users do
      resources :credit_cards, only: [:index]
    end

    resources :stock_locations do
      resources :stock_movements, :stock_items
    end

    get '/config/money', to: 'config#money'
    get '/config', to: 'config#show'

    put '/classifications', to: 'classifications#update', as: :classifications
    get '/taxons/products', to: 'taxons#products', as: :taxon_products
  end
end
