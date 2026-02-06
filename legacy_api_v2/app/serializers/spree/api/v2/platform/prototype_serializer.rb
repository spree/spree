module Spree
  module Api
    module V2
      module Platform
        class PrototypeSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :properties, serializer: Spree.api.platform_property_serializer
          has_many :option_types, serializer: Spree.api.platform_option_type_serializer
          has_many :taxons, serializer: Spree.api.platform_taxon_serializer
        end
      end
    end
  end
end
