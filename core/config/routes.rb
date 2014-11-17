Spree::Core::Engine.draw_routes

Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :users, only: [] do
      resources :store_credits
    end
  end

  namespace :api, defaults: { format: 'json' } do
    resources :store_credit_events, only: [] do
      collection do
        get :mine
      end
    end
  end
end