Spree::Core::Engine.add_routes do
  # Hosted React Dashboard (single-node topology). Serves the built SPA from
  # `Spree::Dashboard.dist_path`; 404s when unconfigured. `format: false`
  # keeps asset extensions (.js, .css, .svg) inside the splat instead of
  # being parsed as a response format.
  get '/dashboard', to: 'dashboard/app#show', as: :dashboard_app
  get '/dashboard/*path', to: 'dashboard/app#show', format: false

  # Hosted seller panel, same topology as the dashboard above. Its own mount
  # rather than a nested route: it is a separate app with its own bundle, and
  # a marketplace that runs no seller panel leaves it unconfigured.
  get '/sellers', to: 'seller_panel/app#show', as: :seller_panel_app
  get '/sellers/*path', to: 'seller_panel/app#show', format: false
end
