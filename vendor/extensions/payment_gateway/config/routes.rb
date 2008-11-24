map.namespace :admin do |admin|
  admin.resources :gateways, :has_many => [:gateway_options]
  admin.resources :gateway_configurations, :has_many => [:gateway_option_values]
end