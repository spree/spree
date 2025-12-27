module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class EventSerializer < BaseSerializer
            include ResourceSerializerConcern

            belongs_to :subscriber
          end
        end
      end
    end
  end
end
