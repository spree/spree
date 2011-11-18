Spree::Core::Engine.routes.prepend do
  namespace :admin do
    resources :promotions do
      resources :promotion_rules
      resources :promotion_actions
    end
  end
end
