Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :users do
      member do
        put :generate_api_key
        put :clear_api_key
      end
    end
  end

  namespace :api, :defaults => { :format => 'json' } do
    resources :products do
      resources :variants
      resources :product_properties
    end

    resources :images
    resources :checkouts do
      member do
        put :next
      end
    end

    resources :variants, :only => [:index] do
    end

    resources :option_types do
      resources :option_values
    end

    resources :orders do
      resources :return_authorizations
      member do
        put :address
        put :delivery
        put :cancel
        put :empty
      end

      resources :line_items
      resources :payments do
        member do
          put :authorize
          put :capture
          put :purchase
          put :void
          put :credit
        end
      end

      resources :shipments, :only => [:create, :update] do
        member do
          put :ready
          put :ship
          put :add
          put :remove
        end
      end
    end

    resources :zones
    resources :countries, :only => [:index, :show]
    resources :states,    :only => [:index, :show]
    resources :addresses, :only => [:show, :update]

    resources :taxonomies do
      member do
        get :jstree
      end
      resources :taxons do
        member do
          get :jstree
        end
      end
    end
    resources :taxons, :only => [:index]
    resources :inventory_units, :only => [:show, :update]
    resources :users
    resources :properties
    resources :stock_locations do
      resources :stock_movements
      resources :stock_items
    end

    get '/config/money', :to => 'config#money'
  end
end
