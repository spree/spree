Spree::Core::Engine.routes.prepend do
  namespace :api do
    scope :module => :v1 do
      resources :products do
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
      end
    end
  end
end
