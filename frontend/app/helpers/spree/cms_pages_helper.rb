module Spree
  module CmsPagesHelper
    def build_section(section)
      preview_type = section.kind.parameterize(separator: '_')

      case section.width
      when 'Half'
        edge_to_edge = ''
        css_width = 'col-6'
      when 'Full'
        edge_to_edge = ''
        css_width = 'col-12'
      when 'Edge-to-Edge'
        edge_to_edge = 'full-width'
        css_width = 'col-12'
      end

      render "spree/cms_pages/sections/#{preview_type}", section: section, width: css_width, edge_to_edge: edge_to_edge
    end
  end
end
