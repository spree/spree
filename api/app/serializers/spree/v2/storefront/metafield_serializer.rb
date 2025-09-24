module Spree
  module V2
    module Storefront
      class MetafieldSerializer < BaseSerializer
        set_type :metafield

        attributes :name, :type

        attribute :key do |metafield|
          metafield.full_key
        end

        attribute :value do |metafield|
          metafield.serialize_value
        end
      end
    end
  end
end
