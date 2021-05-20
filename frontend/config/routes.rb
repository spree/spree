Spree::Core::Engine.add_routes do
  scope '(:locale)', locale: /#{Spree.available_locales.join('|')}/, defaults: { locale: nil } do
    root to: 'home#index'

    resources :products, only: [:index, :show], path: "/#{Spree::Config[:storefront_products_path]}"

    get "/#{Spree::Config[:storefront_products_path]}/:id/related", to: 'products#related'
    # route globbing for pretty nested taxon and product paths
    get "/#{Spree::Config[:storefront_taxons_path]}/*id", to: 'taxons#show', as: :nested_taxons
    get '/product_carousel/:id', to: 'taxons#product_carousel'

    # non-restful checkout stuff
    patch '/checkout/update/:state', to: 'checkout#update', as: :update_checkout
    get '/checkout/:state', to: 'checkout#edit', as: :checkout_state
    get '/checkout', to: 'checkout#edit', as: :checkout

    resources :orders, except: [:index, :new, :create, :destroy]

    resources :addresses, except: [:show]

    get '/cart', to: 'orders#edit', as: :cart
    patch '/cart', to: 'orders#update', as: :update_cart
    put '/cart/empty', to: 'orders#empty', as: :empty_cart

    get '/content/cvv', to: 'content#cvv', as: :cvv
    get '/content/test', to: 'content#test'
    get '/cart_link', to: 'store#cart_link', as: :cart_link
    get '/account_link', to: 'store#account_link', as: :account_link

    get '/locales', to: 'locale#index', as: :locales
    get '/locale/set', to: 'locale#set', as: :set_locale
    get '/currency/set', to: 'currency#set', as: :set_currency

    get '/api_tokens', to: 'store#api_tokens'
    post '/ensure_cart', to: 'store#ensure_cart'
  end
end
