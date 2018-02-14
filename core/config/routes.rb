Spree::Core::Engine.add_routes do
  get '/forbidden', to: 'home#forbidden', as: :forbidden
end

Spree::Core::Engine.draw_routes
