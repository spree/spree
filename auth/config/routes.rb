Rails.application.routes.draw do

  match '/checkout/registration' => 'checkout#registration', :via => :get, :as => :checkout_registration
  match '/checkout/registration' => 'checkout#update_registration', :via => :put, :as => :update_checkout_registration

  match '/login', :to => 'user_sessions#new', :as => :login
  match '/logout', :to => 'user_sessions#destroy', :as => :logout
  match '/signup', :to => 'users#new', :as => :signup

  resource :user_session do
    member do
      get :nav_bar
    end
  end
  resource :account, :controller => "users"
  resources :password_resets
  resources :users

end
