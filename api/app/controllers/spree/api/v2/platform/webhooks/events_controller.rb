module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class EventsController < ResourceController
            private

            def model_class
              Spree::Webhooks::Event
            end

            def scope_includes
              %i[subscriber]
            end

            def resource_serializer
              Spree::Api::Dependencies.platform_webhooks_event_serializer.constantize
            end
          end
        end
      end
    end
  end
end
