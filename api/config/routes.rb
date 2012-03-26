Spree::Core::Engine.routes.prepend do
  namespace :api do
    scope :module => :v1 do
      resources :products
    end
  end
end
