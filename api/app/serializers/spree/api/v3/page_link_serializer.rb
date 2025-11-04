module Spree
  module Api
    module V3
      class PageLinkSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            title: resource.title,
            subtitle: resource.subtitle,
            url: resource.url,
            position: resource.position,
            link_type: resource.link_type,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
