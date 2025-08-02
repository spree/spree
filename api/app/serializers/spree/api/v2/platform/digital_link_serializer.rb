module Spree
  module Api
    module V2
      module Platform
        class DigitalLinkSerializer < BaseSerializer
          set_type :digital_link

          attributes :token, :access_counter

          belongs_to :digital, serializer: Spree::Api::Dependencies.platform_digital_serializer.constantize
          belongs_to :line_item, serializer: Spree::Api::Dependencies.platform_line_item_serializer.constantize
        end
      end
    end
  end
end
