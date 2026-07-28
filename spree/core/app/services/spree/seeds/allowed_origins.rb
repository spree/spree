module Spree
  module Seeds
    class AllowedOrigins
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.each do |store|
          store.allowed_origins.find_or_create_by!(origin: 'http://localhost')
        end
      end
    end
  end
end
