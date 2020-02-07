Spree::Core::Engine.add_routes do
  namespace :graphql do
    post :graphql, to: 'graphql#create'
    post '/auth/login', to: 'graphql#login'
  end
end
