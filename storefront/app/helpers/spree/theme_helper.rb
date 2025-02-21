module Spree
  module ThemeHelper
    def current_page
      @current_page ||= current_theme.pages.find_by(type: 'Spree::Pages::Homepage')
    end

    def current_theme
      @current_theme ||= if params[:theme_id].present?
                           current_store.themes.find_by(id: params[:theme_id])
                         else
                           current_store.default_theme || current_store.themes.first
                         end
    ensure
      @current_theme ||= current_store.themes.first
    end

    def current_theme_preview
      return if params[:theme_preview_id].blank?

      @current_theme_preview ||= current_theme.previews.find_by(id: params[:theme_preview_id])
    end

    def current_page_preview
      return if params[:page_preview_id].blank?

      @current_page_preview ||= current_page.previews.find_by(id: params[:page_preview_id])
    end

    def current_page_or_preview
      @current_page_or_preview ||= current_page_preview || current_page
    end

    def current_theme_or_preview
      @current_theme_or_preview ||= current_theme_preview || current_theme
    end

    def current_header_logo
      @current_header_logo ||= current_theme_or_preview.sections.find_by(type: 'Spree::PageSections::Header')&.logo
    end

    def page_builder_enabled?
      @page_builder_enabled ||= (current_theme_preview.present? || current_page_preview.present?) && params[:page_builder] == 'true'
    end

    def theme_layout_sections
      @theme_layout_sections ||= current_theme_or_preview.sections.includes(:links, { asset_attachment: :blob },
                                                                            { blocks: [:rich_text_text, :links] }).all.each_with_object({}) do |section, hash|
        hash[section.type.to_s.demodulize.underscore] = section
      end
    rescue StandardError => e
      raise e unless Rails.env.production?

      Rails.logger.error("Error rendering theme: #{e.message}")
      Sentry.capture_exception(e)
      {}
    end

    def theme_setting(name)
      if current_theme_preview.present?
        current_theme_preview.preferences.with_indifferent_access[name]
      elsif current_theme.present?
        current_theme.preferences.with_indifferent_access[name]
      end
    end

    # This helper allows us to specify opacity in Tailwind's color palette
    def theme_setting_rgb_components(name)
      hex_color = theme_setting(name)
      return unless hex_color.present?

      rgb = hex_color[0..6].match(/^#(..)(..)(..)$/).captures.map(&:hex)
      rgb.join(', ')
    end

    # https://makandracards.com/makandra/496431-ruby-how-to-convert-hex-color-codes-to-rgb-or-rgba
    def hex_color_to_rgb(hex)
      return unless hex.present?

      rgb = hex[0..6].match(/^#(..)(..)(..)$/).captures.map(&:hex)
      "rgb(#{rgb.join(', ')})"
    end

    def hex_color_to_rgba(hex)
      return unless hex.present?

      *rgb, alpha = hex.match(/^#(..)(..)(..)(..)?$/).captures.map { |hex_pair| hex_pair&.hex }
      opacity = (alpha || 255) / 255.0
      "rgba(#{rgb.join(', ')}, #{opacity.round(2)})"
    end

    def section_styles(section)
      styles = {}

      bg_color = section.preferred_background_color.presence || theme_setting('background_color')
      styles['background-color'] = bg_color
      styles['--section-background'] = bg_color
      text_color = section.preferred_text_color.presence || theme_setting('text_color')
      styles['color'] = text_color
      styles['--section-color'] = text_color
      styles['border-color'] = section.preferred_border_color.presence || theme_setting('border_color')
      styles['padding-top'] = "#{section.preferred_top_padding.presence}px"
      styles['padding-bottom'] = "#{section.preferred_bottom_padding.presence}px"
      styles['border-top-width'] = "#{section.preferred_top_border_width.presence}px"
      border_bottom_width = "#{section.preferred_bottom_border_width.presence}px"
      styles['border-bottom-width'] = border_bottom_width
      styles['--section--border-bottom-width'] = border_bottom_width

      if section.respond_to?(:preferred_button_text_color) && section.preferred_button_text_color.present?
        styles['--button-text-color'] = section.preferred_button_text_color
      end

      if section.respond_to?(:preferred_button_background_color) && section.preferred_button_background_color.present?
        styles['--button-background-color'] = section.preferred_button_background_color
      end

      styles.map { |k, v| "#{k}: #{v}" }.join(';')
    end

    def section_heading_styles(section)
      styles = {}

      styles['text-transform'] = :uppercase if theme_setting('headings_uppercase')
      if section.respond_to?(:preferred_heading_bottom_padding) && section.preferred_heading_bottom_padding.present?
        styles['padding-bottom'] =
          "#{section.preferred_heading_bottom_padding}px"
      end

      styles.compact_blank.map { |k, v| "#{k}: #{v}" }.join(';')
    end

    def block_attributes(block, allowed_styles: :all)
      has_width_desktop = block.respond_to?(:preferred_width_desktop) && block.preferred_width_desktop.present? ? "width-desktop='true'" : nil

      attributes = {
        data: {
          editor_id: "block-#{block.id}",
          editor_name: block.display_name,
          editor_parent_id: "section-#{block.section_id}",
          editor_link: spree.respond_to?(:edit_admin_page_section_block_path) ? spree.edit_admin_page_section_block_path(block.section, block) : nil
        },
        style: block_styles(block, allowed_styles: allowed_styles),
        width_desktop: has_width_desktop
      }.compact_blank

      tag.attributes(attributes)
    end

    def link_attributes(link, as_html: true)
      parent_type = case link.parent_type
                    when 'Spree::PageSection'
                      :section
                    when 'Spree::PageBlock'
                      :block
                    else
                      return ''
                    end

      attributes = if spree.respond_to?(:admin) && spree.respond_to?(:edit_admin_page_link_path) && spree.respond_to?(:edit_admin_page_section_block_path)
                   {
                      data: {
                        editor_id: "link-#{link.id}",
                        editor_name: link.label,
                        editor_parent_id: "#{parent_type}-#{link.parent_id}",
                        editor_link: case parent_type
                                    when :section
                                      spree.edit_admin_page_link_path(link, page_section_id: link.parent_id)
                                    when :block
                                      spree.edit_admin_page_link_path(link, block_id: link.parent_id)
                                    end
                      }
                    }
                  else
                   {}
                  end

      if as_html
        tag.attributes(attributes)
      else
        attributes
      end
    end

    def block_styles(block, allowed_styles: :all)
      styles = {}

      styles['text-align'] = block.preferred_text_alignment if block.respond_to?(:preferred_text_alignment) && block.preferred_text_alignment.present?
      styles['width'] = "#{block.preferred_width_desktop}%" if block.respond_to?(:preferred_width_desktop) && block.preferred_width_desktop.present?
      if block.respond_to?(:preferred_container_alignment)
        styles['margin'] = case block.preferred_container_alignment
                           when 'center'
                             '0 auto'
                           when 'right'
                             '0 0 0 auto'
                           else
                             '0 auto 0 0'
                           end
      end
      styles['color'] = if block.respond_to?(:preferred_text_color) && block.preferred_text_color.present?
                          block.preferred_text_color
                        else
                          'var(--section-color)'
                        end

      styles['padding-top'] = "#{block.preferred_top_padding}px" if block.respond_to?(:preferred_top_padding) && block.preferred_top_padding.present?
      if block.respond_to?(:preferred_bottom_padding) && block.preferred_bottom_padding.present?
        styles['padding-bottom'] = "#{block.preferred_bottom_padding}px"
      end
      styles['text-transform'] = :uppercase if theme_setting('headings_uppercase') && block.type == 'heading'
      styles['background-color'] = if block.respond_to?(:preferred_background_color) && block.preferred_background_color.present?
                                     block.preferred_background_color
                                   else
                                     'var(--section-background)'
                                   end

      if block.respond_to?(:preferred_button_background_color) && block.preferred_button_background_color.present?
        styles['--button-background-color'] = block.preferred_button_background_color
      end
      if block.respond_to?(:preferred_button_text_color) && block.preferred_button_text_color.present?
        styles['--button-text-color'] = block.preferred_button_text_color
      end

      styles = styles.compact_blank
      styles = styles.slice(*allowed_styles) if allowed_styles != :all

      styles.map { |k, v| "#{k}: #{v}" }.join(';')
    end

    def block_background_color_style(block)
      return nil unless block.respond_to?(:preferred_background_color) && block.preferred_background_color.present?

      "background-color: #{block.preferred_background_color};"
    end

    def block_css_classes(block)
      classes = []
      classes << "justify-#{block.preferred_justify}" if block.respond_to?(:preferred_justify) && block.preferred_justify.present?
      classes.join(',')
    end
  end
end
