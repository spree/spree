Rails.application.routes.draw do |map|
  namespace :admin do
    resources :users do
      member do
        put :generate_api_key
        put :clear_api_key
      end
    end
  end

  namespace :api do
    resources :shipments, :except => [:new,:edit] do
      put :event, :on => :member
      resources :inventory_units, :except => [:new,:edit] do
        put :event, :on => :member
      end
    end
    resources :orders, :except => [:new,:edit] do
      put :event, :on => :member
      resources :shipments, :except => [:new,:edit]
      resources :line_items, :except => [:new,:edit]
      resources :inventory_units, :except => [:new,:edit] do
        put :event, :on => :member
      end
    end
    resources :inventory_units, :except => [:new,:edit] do
      put :event, :on => :member
    end
    resources :products, :except => [:new,:edit]
    resources :countries, :except => [:new,:edit] do
      resources :states, :except => [:new,:edit]
    end
    resources :states, :except => [:new,:edit]
  end

end