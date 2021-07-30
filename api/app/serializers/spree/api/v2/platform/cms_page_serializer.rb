module Spree
  module Api
    module V2
      module Platform
        class CmsPageSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_many :cms_sections, serializer: :cms_section
        end
      end
    end
  end
end
