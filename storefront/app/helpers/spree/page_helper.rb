module Spree
  module PageHelper
    def render_page(page = nil, variables = {})
      page ||= current_page

      sections = current_page_preview.present? ? current_page_preview.sections : page.sections
      sections_html = sections.includes(:links, { asset_attachment: :blob }, { blocks: [:rich_text_text, :links] }).map do |section|
        render_section(section, variables)
      end.join.html_safe

      "<main class='page-contents'>#{sections_html}</main>".html_safe
    end

    def render_section(section, variables = {}, lazy_allowed: true)
      return '' if section.blank?

      variables[:section] = section
      variables[:loaded] = true

      css_id = "section-#{section.id}"
      css_class = "section-#{section.class.name.demodulize.underscore.dasherize}"

      if page_builder_enabled?
        turbo_frame_tag(css_id, class: css_class) do
          content_tag(:div,
            data: {
              editor_id: css_id,
              editor_name: section.name,
              editor_link: spree.edit_admin_page_section_path(section)
            }
          ) do
            render('/' + section.to_partial_path, **variables)
          end
        end
      elsif section.lazy? && lazy_allowed
        variables[:loaded] = false
        variables[:url_options] = { locale: I18n.locale }

        path = section.lazy_path(variables)

        turbo_frame_tag(css_id, src: path, loading: 'eager', class: css_class) do
          render('/' + section.to_partial_path, **variables)
        end
      else
        content_tag(:div, id: css_id, class: css_class) do
          render('/' + section.to_partial_path, **variables)
        end
      end
    rescue ActionView::MissingTemplate, ActionView::Template::Error => e
      raise e unless Rails.env.production?

      Spree::Dependencies.error_handler.constantize.call(exception: e, extra: { section: section })
      ''
    end

    def page_builder_link_to(link, options = {}, &block)
      if link.present?
        link_to(spree_storefront_resource_url(link.linkable || link), options.except(:label)) do
          block.present? ? block.call : options[:label]
        end
      else
        block&.call&.html_safe
      end
    end
  end
end
