Spree::Core::Engine.add_routes do
  scope '(:locale)', locale: /#{Spree.available_locales.join('|')}/, defaults: { locale: nil } do
    namespace :account do
      resource :wishlist, only: [:show], controller: '/spree/wishlists' do
        resources :wished_items, only: [:create, :destroy]
      end
    end

    root to: 'home#index'
  end
end
