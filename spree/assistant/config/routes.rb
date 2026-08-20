Spree::Core::Engine.add_routes do
  namespace :api do
    namespace :v3 do
      namespace :admin do
        # Availability — the dashboard asks before rendering the panel.
        resource :assistant, only: [:show], controller: 'assistant'

        namespace :assistant do
          resources :chats, only: %i[index create show destroy] do
            resources :messages, only: [:create]

            resources :tool_calls, only: [] do
              member do
                post :approve
                post :reject
              end
            end
          end
        end
      end
    end
  end
end
