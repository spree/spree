module Spree
  module CmsPagesHelper
    def build_section(section)
      preview_type = section.kind.parameterize(separator: '_')

      case section.width
      when 'Full'
        css_width = 'col-12'
      when 'Half'
        css_width = 'col-6'
      end

      render "spree/cms_pages/sections/#{preview_type}", section: section, width: css_width
    end
  end
end
