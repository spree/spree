Spree::Core::Engine.routes.prepend do
  namespace :admin do
    resources :users do
      member do
        put :generate_api_key
        put :clear_api_key
      end
    end
  end

  namespace :api do
    scope :module => :v1 do
      resources :products do
        collection do
          get :search
        end

        resources :variants
      end

      resources :images

      resources :variants, :only => [:index] do
      end

      resources :orders do
        collection do
          get :search
        end
        member do
          put :address
          put :delivery
          put :cancel
        end

        resources :line_items
        resources :payments do
          member do
            put :authorize
            put :purchase
            put :void
            put :credit
          end
        end

        resources :shipments do
          member do
            put :ready
            put :ship
          end
        end
      end

      resources :zones
      resources :countries, :only => [:index, :show]
      resources :addresses, :only => [:show, :update]
      resources :taxonomies do
        resources :taxons
      end
    end
  end
end
