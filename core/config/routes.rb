Spree::Core::Engine.add_routes do
  get '/forbidden', to: 'errors#forbidden', as: :forbidden
  get '/unauthorized', to: 'errors#unauthorized', as: :unauthorized
end

Spree::Core::Engine.draw_routes
