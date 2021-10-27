module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodSerializer < BaseSerializer
          attributes :name, :type, :description, :active, :display_on, :auto_capture, :position

          has_many :stores
        end
      end
    end
  end
end
