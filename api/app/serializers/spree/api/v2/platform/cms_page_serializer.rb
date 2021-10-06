module Spree
  module Api
    module V2
      module Platform
        class CmsPageSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :cms_sections, serializer: :cms_section
        end
      end
    end
  end
end
