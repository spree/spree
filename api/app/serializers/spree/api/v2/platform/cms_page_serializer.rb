module Spree
  module Api
    module V2
      module Platform
        class CmsPageSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern
        end
      end
    end
  end
end
