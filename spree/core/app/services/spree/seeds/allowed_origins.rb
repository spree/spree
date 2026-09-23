module Spree
  module Seeds
    class AllowedOrigins
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        store.allowed_origins.find_or_create_by!(origin: 'http://localhost')
      end
    end
  end
end
