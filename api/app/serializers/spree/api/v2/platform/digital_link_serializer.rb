module Spree
  module Api
    module V2
      module Platform
        class DigitalLinkSerializer < BaseSerializer
          set_type :digital_link

          attributes :token, :access_counter

          belongs_to :digital, serializer: Spree.api.platform_digital_serializer
          belongs_to :line_item, serializer: Spree.api.platform_line_item_serializer
        end
      end
    end
  end
end
