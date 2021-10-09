module Spree
  module V2
    module Storefront
      class DigitalLinkSerializer < BaseSerializer
        set_type :digital_link

        attributes :token
      end
    end
  end
end
