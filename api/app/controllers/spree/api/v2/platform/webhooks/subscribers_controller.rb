module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class SubscribersController < ResourceController
            private

            def model_class
              Spree::Webhooks::Endpoint
            end

            def permitted_resource_params
              params.
                require(:subscriber).
                permit(spree_permitted_attributes.push(*%i[enabled subscriptions url]))
            end
          end
        end
      end
    end
  end
end
