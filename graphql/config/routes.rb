Spree::Core::Engine.add_routes do
  resource :graphql, only: :create, controller: :graphql
  resource :jwt, only: :create, controller: :jwt
end
