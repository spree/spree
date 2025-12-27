# frozen_string_literal: true

Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v2 do
      namespace :platform do
        # Legacy Webhooks API
        namespace :webhooks do
          resources :events, only: :index
          resources :subscribers
        end
      end
    end
  end

  namespace :admin do
    resources :webhooks_subscribers
  end
end
