module Spree
  module CmsPagesHelper
    def simple_page?(page)
      page.content.present? && !page.sections?
    end

    def section_tags(section, &block)
      inner_content = content_tag(:div, class: section.css_classes, &block)

      if section.fullscreen?
        inner_content
      else
        content_tag(:div, inner_content, class: 'container')
      end
    end

    def build_section(section)
      section_tags(section) do
        render "spree/shared/cms/sections/#{spree_resource_path(section)}", section: section
      end
    end
  end
end
