module Spree
  class CmsPage < Spree::Base
    PAGE_KINDS = ['Standard Page','Home Page']

    belongs_to :store, touch: true
    has_many :cms_sections
  end
end
