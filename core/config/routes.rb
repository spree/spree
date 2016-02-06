Spree::Core::Engine.add_routes do
  get '/forbidden', to: 'home#forbidden', as: :forbidden
  # those routes are needed for mailers
  root to: 'home#index'
  resources :products, only: [:index, :show]
end

Spree::Core::Engine.draw_routes
