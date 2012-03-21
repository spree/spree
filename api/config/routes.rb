Spree::Api::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :products
    end
  end
end
