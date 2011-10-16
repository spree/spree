Spree::Promo::Engine.routes.draw do
  namespace :spree do
    namespace :admin do
      resources :promotions do
        resources :promotion_rules
        resources :promotion_actions
      end
    end
  end
end
