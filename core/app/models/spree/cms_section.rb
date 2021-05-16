module Spree
  class CmsSection < Spree::Base
    acts_as_list scope: :cms_page
    belongs_to :cms_page

    SECTION_WIDTHS = ['Full', 'Half']
  end
end
