module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class EndpointSerializer < BaseSerializer
            set_type :webhooks_endpoint

            attributes :enabled, :url, :subscriptions
          end
        end
      end
    end
  end
end
