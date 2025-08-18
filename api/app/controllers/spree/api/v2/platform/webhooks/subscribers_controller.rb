module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class SubscribersController < ResourceController
            private

            def model_class
              Spree::Webhooks::Subscriber
            end

            def spree_permitted_attributes
              super + [{ subscriptions: [] }]
            end

            def resource_serializer
              Spree::Api::Dependencies.platform_webhooks_subscriber_serializer.constantize
            end
          end
        end
      end
    end
  end
end
