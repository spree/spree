module Spree
  module Api
    module V2
      module Platform
        class PrototypeSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :properties, serializer: Spree::Api::Dependencies.platform_property_serializer.constantize
          has_many :option_types, serializer: Spree::Api::Dependencies.platform_option_type_serializer.constantize
          has_many :taxons, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
        end
      end
    end
  end
end
