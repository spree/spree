module Spree
  module Api
    module V2
      module Platform
        module Webhooks
          class SubscriberSerializer < BaseSerializer
            include ResourceSerializerConcern
          end
        end
      end
    end
  end
end
