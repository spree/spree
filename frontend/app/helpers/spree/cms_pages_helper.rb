module Spree
  module CmsPagesHelper
    def simple_page?(page)
      page.content.present? && !page.sections?
    end

    def section_tags(section, width, fit, &block)
      inner_content = content_tag(:div, class: fit, &block)
      if section.width == 'Half'
        content_tag(:aside, inner_content, class: width)
      else
        content_tag(:div, inner_content, class: width)
      end
    end

    def build_section(section)
      css_width = if section.full_width_on_small
                    case section.width
                    when 'Half'
                      'cms_section col-12 col-md-6 cms_half_section half_section_on_md_up'
                    when 'Full'
                      'cms_section col-12 cms_full_section'
                    else
                      ''
                    end
                  else
                    case section.width
                    when 'Half'
                      'cms_section col-6 cms_half_section'
                    when 'Full'
                      'cms_section col-12 cms_full_section'
                    else
                      ''
                    end
                  end

      fit = case section.fit
            when 'Screen'
              'full-width '
            else
              ''
            end

      section_tags(section, css_width, fit) do
        render "spree/shared/cms/sections/#{spree_resource_path(section)}", section: section
      end
    end
  end
end
