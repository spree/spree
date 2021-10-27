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
          end
        end
      end
    end
  end
end
