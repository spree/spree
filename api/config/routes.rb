Spree::Core::Engine.routes.prepend do
  namespace :api do
    scope :module => :v1 do
      resources :products do
        collection do
          get :search
        end

        resources :variants
        resources :images
      end

      resources :variants, :only => [:index] do
        resources :images
      end

      resources :orders do
        member do
          put :address
          put :delivery
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
      end

      resources :countries, :only => [:index, :show]
    end
  end
end
