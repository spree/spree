module Spree
  module Emails
    # What comes out of an exchange in place of a unit going back.
    class ReplacementItemSerializer < Spree::Emails::BaseSerializer
      attributes :quantity

      attribute :name do |line|
        line.new_variant&.name
      end

      attribute :options_text do |line|
        line.new_variant&.options_text
      end
    end
  end
end
