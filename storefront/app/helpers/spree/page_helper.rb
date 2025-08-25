module Spree
  module PageHelper
    # Renders the page with the current theme (or theme preview) and page preview if it exists.
    # It fetches all page sections and renders them one by one in the order they are set in the page builder by store staff.
    # It also handles lazy loading of sections.
    #
    # @param page [Spree::Page] the page to render
    # @param variables [Hash] variables to pass to the page sections
    # @option variables [Array] :pickup_locations ([]) the pickup locations to pass to the page sections
    # @return [String] the rendered page
    def render_page(page = nil, variables = {})
      page ||= current_page

      sections = current_page_preview.present? ? current_page_preview.sections : page.sections
      sections_html = sections.includes(:links, :rich_text_text, :rich_text_description, { asset_attachment: :blob }, { blocks: [:rich_text_text, :links] }).map do |section|
        render_section(section, variables)
      end.join.html_safe

      "<main class='page-contents'>#{sections_html}</main>".html_safe
    end

    # Renders a single section of the page.
    #
    # @param section [Spree::PageSection] the section to render
    # @param variables [Hash] variables to pass to the section
    # @option variables [Boolean] :lazy_allowed (true) whether lazy loading is allowed for the section (if it supports it)
    # @return [String] the rendered section
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

      Rails.error.report(e, context: { section_id: section.id }, source: 'spree.storefront')

      ''
    end

    # Renders a link to the page builder for the given link.
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
