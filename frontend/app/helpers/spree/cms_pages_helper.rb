module Spree
  module CmsPagesHelper
    def simple_page?(page)
      page.content.present? && !page.sections?
    end

    def build_section(section)
      preview_type = section.type.parameterize(separator: '_')

      case section.width
      when 'Half'
        element = 'aside'
        css_width = 'col-6 cms_half_section'
      when 'Full'
        element = 'div'
        css_width = 'col-12'
      else
        element = 'div'
        css_width = ''
      end

      boundary = case section.boundary
                 when 'Screen'
                   'full-width'
                 else
                   ''
                 end

      render "spree/shared/cms/sections/#{preview_type}", section: section,
                                                          width: css_width,
                                                          boundary: boundary,
                                                          element: element
    end
  end
end
