module Spree
  module Api
    module V2
      module Platform
        class OptionValueSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :option_type, serializer: Spree::Api::Dependencies.platform_option_type_serializer.constantize
        end
      end
    end
  end
end
