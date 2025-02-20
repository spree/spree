Spree::Core::Engine.add_routes do
  scope '(:locale)', locale: /#{Spree.available_locales.join('|')}/, defaults: { locale: nil } do
    # Cart
    resources :orders, except: [:index, :new, :create, :destroy]
    resources :line_items, only: [:create, :update, :destroy]
    get '/cart', to: 'orders#edit', as: :cart
    patch '/cart', to: 'orders#update', as: :update_cart

    resources :addresses, except: [:index]
    namespace :account do
      resource :wishlist, only: [:show], controller: '/spree/wishlists' do
        resources :wished_items, only: [:create, :destroy]
      end
    # Wishlists
    resources :wishlists, only: [:show] # for sharing with ID and Token

    end

    root to: 'home#index'
  end
end
