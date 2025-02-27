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

      if page_builder_enabled?
        turbo_frame_tag("section-#{section.id}") do
          content_tag(:div,
            data: {
              editor_id: "section-#{section.id}",
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

        turbo_frame_tag("section-#{section.id}", src: path, loading: 'eager') do
          render('/' + section.to_partial_path, **variables)
        end
      else
        render('/' + section.to_partial_path, **variables)
      end
    rescue ActionView::MissingTemplate, ActionView::Template::Error => e
      raise e unless Rails.env.production?

      Rails.logger.error("Missing template for section: #{section.type}")
      Sentry.capture_exception(e, extra: { section: section })
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
