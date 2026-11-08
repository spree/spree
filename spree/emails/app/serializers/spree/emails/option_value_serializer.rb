module Spree
  module Emails
    class OptionValueSerializer < Spree::Api::V3::OptionValueSerializer
      _attributes.delete(:custom_fields)
    end
  end
end
