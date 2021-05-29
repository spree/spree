module Spree::Cms::Sections
  class Promo < Spree::CmsSection
    def links_to
      ['Spree::Taxon', 'Spree::Product']
    end

    def widths
      ['Half']
    end
  end
end
