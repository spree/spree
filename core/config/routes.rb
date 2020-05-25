Spree::Core::Engine.add_routes do
  forbidden_contoller = defined?(Spree::HomeControler) ? 'home' : 'errors'
  get '/forbidden', to: "#{forbidden_contoller}#forbidden", as: :forbidden
end

Spree::Core::Engine.draw_routes
