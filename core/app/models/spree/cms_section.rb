module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    TYPES = ['Spree::Cms::Sections::Hero',
             'Spree::Cms::Sections::Promo',
             'Spree::Cms::Sections::FeaturedArticle']

    def links_to
      []
    end

    def widths
      []
    end
  end
end
