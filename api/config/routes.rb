Spree::Core::Engine.routes.prepend do
  namespace :api do
    scope :module => :v1 do
      resources :products do
        resources :variants
      end

      resources :variants, :only => [:index]

      resources :orders do
        member do
          put :address
        end

        resources :line_items
      end
    end
  end
end
