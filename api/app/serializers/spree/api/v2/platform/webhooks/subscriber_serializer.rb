module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class SubscriberSerializer < BaseSerializer
            set_type :webhooks_subscriber

            attributes :active, :url, :subscriptions
          end
        end
      end
    end
  end
end
