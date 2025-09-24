module Spree
  module V2
    module Storefront
      class MetafieldSerializer < BaseSerializer
        set_type :metafield

        attributes :name, :value

        attribute :key do |metafield|
          metafield.full_key
        end

        attribute :
      end
    end
  end
end
