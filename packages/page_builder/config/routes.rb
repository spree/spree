Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    # storefront / page builder
    resource :storefront, only: [:edit, :update], controller: :storefront
    resources :themes, except: [:new, :show] do
      member do
        put :update_with_page
        put :publish
        post :clone
      end
      resources :sections, controller: 'page_sections', only: %i[new create] do
        member do
          patch :move_higher
          patch :move_lower
        end
      end
    end
    resources :pages, except: [:show] do
      resources :sections, controller: 'page_sections', only: %i[new create] do
        member do
          patch :move_higher
          patch :move_lower
        end
      end
    end
    resources :page_sections, only: %i[edit update destroy] do
      member do
        patch :restore_design_settings_to_defaults
      end

      resources :blocks, controller: 'page_blocks' do
        member do
          patch :move_higher
          patch :move_lower
        end

        resources :links, controller: 'page_links', only: [:create]
      end
      resources :links, controller: 'page_links', only: [:create]
    end
    resources :page_links, only: [:edit, :update, :destroy]
  end
end
