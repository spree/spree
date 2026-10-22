module Spree
  module Emails
    class AddressSerializer < Spree::Api::V3::AddressSerializer
      _attributes.delete(:owner)
    end
  end
end
