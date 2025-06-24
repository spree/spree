module Spree
  module Api
    module V2
      module Platform
        class GiftCardSerializer < BaseSerializer
          include ResourceSerializerConcern

          set_type :gift_card

          belongs_to :user

          has_many :orders
        end
      end
    end
  end
end
