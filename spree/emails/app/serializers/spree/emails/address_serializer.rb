module Spree
  module Emails
    class AddressSerializer < Spree::Api::V3::AddressSerializer
      _attributes.delete(:owner)
      _attributes.delete(:custom_fields)
    end
  end
end
