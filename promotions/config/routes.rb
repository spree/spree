Rails.application.routes.draw do |map|
  namespace :admin do
    resources :promotions do
      resources :promotion_rules
    end
  end
end
