Spree::Core::Engine.add_routes do
  scope '(:locale)', locale: /#{Spree.available_locales.join('|')}/, defaults: { locale: nil } do
    # store password protection
    get '/password', to: 'password#show', as: :password
    post '/password', to: 'password#check', as: :check_password

    # Product Catalog
    resources :products, only: [:index, :show], path: '/products' do
      member do
        get :related
      end
    end
    get '/t/*id', to: 'taxons#show', as: :nested_taxons
    get '/tx/:id', to: 'taxonomies#show', as: :taxonomy

    # Pages
    resources :pages, only: [:show]
    resources :policies, only: %i[show]

    # Page Sections (used for lazy loading, eg. product carousels)
    resources :page_sections, only: [:show]

    # Search
    get '/search', to: 'search#show', as: :search
    get '/search/suggestions', to: 'search#suggestions', as: :search_suggestions

    # Posts
    resources :posts, only: [:index, :show] do
      member do
        get :related_products
      end
    end
    get '/posts/tag/:tag', to: 'posts#index', as: :tagged_posts
    get '/posts/category/:category_id', to: 'posts#index', as: :category_posts

    # Cart
    resources :orders, except: [:index, :new, :create, :destroy]
    resources :line_items, only: [:create, :update, :destroy]
    get '/cart', to: 'orders#edit', as: :cart
    patch '/cart', to: 'orders#update', as: :update_cart

    # Checkout
    get '/checkout/:token/complete', to: 'checkout#complete', as: :checkout_complete
    patch '/checkout/:token/apply_coupon_code', as: :checkout_apply_coupon_code, to: 'checkout#apply_coupon_code'
    delete '/checkout/:token/remove_coupon_code', as: :checkout_remove_coupon_code, to: 'checkout#remove_coupon_code'
    patch '/checkout/:token/apply_store_credit', as: :checkout_apply_store_credit, to: 'checkout#apply_store_credit'
    delete '/checkout/:token/remove_store_credit', as: :checkout_remove_store_credit, to: 'checkout#remove_store_credit'
    get '/checkout/:token/:state', to: 'checkout#edit', as: :checkout_state
    patch '/checkout/:token/update/:state', to: 'checkout#update', as: :update_checkout
    get '/checkout/:token', to: 'checkout#edit', as: :checkout
    delete '/checkout/:token/remove_missing_items', to: 'checkout#remove_missing_items', as: :checkout_remove_missing_items

    # Account
    resources :addresses, except: [:index]
    resource :account, to: redirect('/account/orders')
    namespace :account do
      resource :profile, controller: :profile, only: [:edit, :update]
      resources :orders, only: [:index, :show]
      resources :addresses, only: [:index]
      resource :wishlist, only: [:show], controller: '/spree/wishlists' do
        resources :wished_items, only: [:create, :destroy]
      end
      resource :newsletter, only: [:edit, :update], controller: :newsletter
      resources :store_credits, only: [:index]
      resources :gift_cards, only: [:index]
    end

    # Wishlists
    resources :wishlists, only: [:show] # for sharing with ID and Token

    # Order Status
    resource :order_statuses, only: [:new, :create], path: 'order_status', as: :order_status, controller: 'order_status'

    # Settings
    resource :settings, only: [:update, :show]

    # Newsletter
    resources :newsletter_subscribers, only: [:create] do
      get :verify, on: :collection
    end

    # Contact form
    resources :contacts, only: [:new, :create]
    get '/contact', to: 'contacts#new', as: 'contact'

    # Digital Links
    resources :digital_links, only: [:show]

    root to: 'home#index'
  end

  get 'robots.txt' => 'seo#robots'
  get 'sitemap' => 'seo#sitemap'
  get 'sitemap.xml.gz' => 'seo#sitemap'
end
