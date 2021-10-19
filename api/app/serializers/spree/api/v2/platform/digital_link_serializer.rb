module Spree
  module Api
    module V2
      module Platform
        class DigitalLinkSerializer < BaseSerializer
          set_type :digital_link

          attributes :token, :access_counter

          belongs_to :digital
          belongs_to :line_item
        end
      end
    end
  end
end
