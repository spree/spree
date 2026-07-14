Spree::Core::Engine.add_routes do
  # Hosted React Dashboard (single-node topology). Serves the built SPA from
  # `Spree::Dashboard.dist_path`; 404s when unconfigured. `format: false`
  # keeps asset extensions (.js, .css, .svg) inside the splat instead of
  # being parsed as a response format.
  get '/dashboard', to: 'dashboard/app#show', as: :dashboard_app
  get '/dashboard/*path', to: 'dashboard/app#show', format: false
end
