module Spree
  module ThemeHelper
    # Returns the current page, if not found it will fallback to the homepage
    #
    # @return [Spree::Page] the current page
    def current_page
      @current_page ||= current_theme.pages.find_by(type: 'Spree::Pages::Homepage')
    end

    # Returns the current theme, if not found it will fallback to the default theme
    # If `theme_id` is provided in the params, it will return the theme with the given id
    #
    # @return [Spree::Theme] the current theme
    def current_theme
      @current_theme ||= if params[:theme_id].present?
                           current_store.themes.find_by(id: params[:theme_id])
                         else
                           current_store.default_theme || current_store.themes.first
                         end
    ensure
      @current_theme ||= current_store.themes.first
    end

    # Returns the current theme preview
    #
    # @return [Spree::ThemePreview] the current theme preview
    def current_theme_preview
      return if params[:theme_preview_id].blank?

      @current_theme_preview ||= current_theme.previews.find_by(id: params[:theme_preview_id])
    end

    # Returns the current page preview
    #
    # @return [Spree::PagePreview] the current page preview
    def current_page_preview
      return if params[:page_preview_id].blank?

      @current_page_preview ||= current_page.previews.find_by(id: params[:page_preview_id])
    end

    # Returns the current page or page preview, preview takes priority
    #
    # @return [Spree::Page] the current page or page preview
    def current_page_or_preview
      @current_page_or_preview ||= current_page_preview || current_page
    end

    # Returns the current theme or theme preview, preview takes priority
    #
    # @return [Spree::Theme] the current theme or theme preview
    def current_theme_or_preview
      @current_theme_or_preview ||= current_theme_preview || current_theme
    end

    # Returns the logo set in the `Spree::PageSections::Header` section
    #
    # @return [ActiveStorage::Attachment] the logo
    def current_header_logo
      @current_header_logo ||= current_theme_or_preview.sections.find_by(type: 'Spree::PageSections::Header')&.logo
    end

    # Returns whether the page builder is enabled
    # It checks if there is a theme preview or page preview and if the `page_builder` param is set to `true`
    #
    # @return [Boolean] whether the page builder is enabled
    def page_builder_enabled?
      @page_builder_enabled ||= (current_theme_preview.present? || current_page_preview.present?) && params[:page_builder] == 'true'
    end

    # Returns whether the page cache is enabled
    #
    # @return [Boolean] whether the page cache is enabled
    def page_cache_enabled?
      @page_cache_enabled ||= Spree::Storefront::Config.page_cache_enabled
    end

    # Returns the theme layout sections, eg. header, footer, etc.
    #
    # @return [Hash] the theme layout sections
    def theme_layout_sections
      Spree::Deprecation.warn('theme_layout_sections is deprecated and will be removed in Spree 6.0. Please use render_header_sections and render_footer_sections instead.')

      @theme_layout_sections ||= current_theme_or_preview.sections.includes(section_includes).all.each_with_object({}) do |section, hash|
        hash[section.type.to_s.demodulize.underscore] = section
      end
    rescue StandardError => e
      raise e unless Rails.env.production?

      Rails.error.report(e, context: { theme_id: current_theme_or_preview.id }, source: 'spree.storefront')

      {}
    end

    # Returns the theme setting for the given name
    # if preview is present, it will return the preview setting, otherwise it will return the theme setting
    #
    # @param name [String] the name of the theme setting
    # @return [String] the theme setting
    def theme_setting(name)
      if current_theme_preview.present?
        current_theme_preview.preferences.with_indifferent_access[name]
      elsif current_theme.present?
        current_theme.preferences.with_indifferent_access[name]
      end
    end

    # This helper allows us to specify opacity in Tailwind's color palette
    #
    # @param name [String] the name of the theme setting
    # @return [String] the theme setting
    def theme_setting_rgb_components(name)
      hex_color = theme_setting(name)
      return unless hex_color.present?

      rgb = hex_color[0..6].match(/^#(..)(..)(..)$/).captures.map(&:hex)
      rgb.join(', ')
    end

    # https://makandracards.com/makandra/496431-ruby-how-to-convert-hex-color-codes-to-rgb-or-rgba
    # Converts a hex color to rgb
    #
    # @param hex [String] the hex color
    # @return [String] the rgb color
    def hex_color_to_rgb(hex)
      return unless hex.present?

      rgb = hex[0..6].match(/^#(..)(..)(..)$/).captures.map(&:hex)
      "rgb(#{rgb.join(', ')})"
    end

    # Converts a hex color to rgba
    #
    # @param hex [String] the hex color
    # @return [String] the rgba color
    def hex_color_to_rgba(hex)
      return unless hex.present?

      *rgb, alpha = hex.match(/^#(..)(..)(..)(..)?$/).captures.map { |hex_pair| hex_pair&.hex }
      opacity = (alpha || 255) / 255.0
      "rgba(#{rgb.join(', ')}, #{opacity.round(2)})"
    end

    # Returns the section inline CSS styles
    #
    # @param section [Spree::PageSection] the section
    # @return [String] the section inline CSS styles
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

    # Returns the section heading inline CSS styles
    #
    # @param section [Spree::PageSection] the section
    # @return [String] the section heading inline CSS styles
    def section_heading_styles(section)
      styles = {}

      styles['text-transform'] = :uppercase if theme_setting('headings_uppercase')
      if section.respond_to?(:preferred_heading_bottom_padding) && section.preferred_heading_bottom_padding.present?
        styles['padding-bottom'] =
          "#{section.preferred_heading_bottom_padding}px"
      end

      styles.compact_blank.map { |k, v| "#{k}: #{v}" }.join(';')
    end

    # Returns the block HTML attributes
    # it automatically adds data attributes for page builder
    #
    # @param block [Spree::PageBlock] the block
    # @return [Hash] the block attributes
    def block_attributes(block, allowed_styles: :all)
      has_width_desktop = block.respond_to?(:preferred_width_desktop) && block.preferred_width_desktop.present? ? "width-desktop='true'" : nil

      attributes = {
        data: {
          editor_id: "block-#{block.id}",
          editor_name: block.display_name,
          editor_parent_id: "section-#{block.section_id}",
          editor_link: spree.respond_to?(:edit_admin_page_section_block_path) ? spree.edit_admin_page_section_block_path(block.section, block) : nil
        },
        id: "block-#{block.id}",
        class: "block-#{block.class.name.demodulize.underscore.dasherize}",
        style: block_styles(block, allowed_styles: allowed_styles),
        width_desktop: has_width_desktop
      }.compact_blank

      tag.attributes(attributes)
    end

    # Returns the link HTML attributes
    # it automatically adds data attributes for page builder
    #
    # @param link [Spree::PageLink] the link
    # @return [Hash] the link attributes
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
                      },
                      id: "link-#{link.id}",
                      class: "link-#{link.class.name.demodulize.underscore.dasherize}"
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

    # Returns the block inline CSS styles
    #
    # @param block [Spree::PageBlock] the block
    # @param allowed_styles [Symbol] the allowed styles, if not provided, all styles will be returned
    # @return [String] the block inline CSS styles
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

    # Returns the block background color style
    #
    # @param block [Spree::PageBlock] the block
    # @return [String] the block background color style
    def block_background_color_style(block)
      return nil unless block.respond_to?(:preferred_background_color) && block.preferred_background_color.present?

      "background-color: #{block.preferred_background_color};"
    end

    # Returns the block CSS classes
    #
    # @param block [Spree::PageBlock] the block
    # @return [String] the block CSS classes
    def block_css_classes(block)
      classes = []
      classes << "justify-#{block.preferred_justify}" if block.respond_to?(:preferred_justify) && block.preferred_justify.present?
      classes.join(',')
    end
  end
end
