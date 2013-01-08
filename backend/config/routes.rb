Spree::Core::Engine.routes.append do
  namespace :admin do
    get '/search/users', :to => "search#users", :as => :search_users

    resources :promotions do
      resources :promotion_rules
      resources :promotion_actions
    end

    resources :adjustments
    resources :zones
    resources :banners do
      member do
        post :dismiss
      end
    end
    resources :countries do
      resources :states
    end
    resources :states
    resources :tax_categories

    resources :products do
      collection do
        get :search
      end

      resources :product_properties
      resources :images do
        collection do
          post :update_positions
        end
      end
      member do
        get :clone
      end
      resources :variants do
        collection do
          post :update_positions
        end
      end
    end

    get '/variants/search', :to => "variants#search", :as => :search_variants

    resources :option_types do
      collection do
        post :update_positions
        post :update_values_positions
      end
    end

    delete '/option_values/:id', :to => "option_values#destroy", :as => :option_value

    resources :properties do
      collection do
        get :filtered
      end
    end

    resources :prototypes do
      member do
        get :select
      end

      collection do
        get :available
      end
    end

    resource :inventory_settings
    resource :image_settings

    resources :orders do
      member do
        put :fire
        get :fire
        post :resend
        get :open_adjustments
        get :close_adjustments
      end

      resource :customer, :controller => "orders/customer_details"

      resources :adjustments do
        member do
          get :toggle_state
        end
      end
      resources :line_items
      resources :shipments do
        member do
          put :fire
        end
      end
      resources :return_authorizations do
        member do
          put :fire
        end
      end
      resources :payments do
        member do
          put :fire
        end
      end
    end

    resource :general_settings do
      collection do
        post :dismiss_alert
      end
    end

    resources :taxonomies do
      collection do
      	post :update_positions
      end
      member do
        get :get_children
      end
      resources :taxons
    end

    resources :taxons, :only => [] do
      collection do
        get :search
      end
    end

    resources :reports, :only => [:index, :show] do
      collection do
        get :sales_total
        post :sales_total
      end
    end

    resources :shipping_methods
    resources :shipping_categories
    resources :tax_rates
    resource  :tax_settings

    resources :trackers
    resources :payment_methods
    resources :mail_methods do
      member do
        post :testmail
      end
    end
  end

  match '/admin', :to => 'admin/orders#index', :as => :admin
end
