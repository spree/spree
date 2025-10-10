module Spree
  module FontsHelper
    def normal_font_family_styles
      return '' if current_theme_or_preview.preferred_font_family.blank?

      font_family = current_theme_or_preview.preferred_font_family
      text_font_size = (current_theme_or_preview.preferred_font_size_scale || 100) / 100.0

      <<~CSS
        :root {
          --font-body: #{font_family};
        }

        body {
          font-family: '#{font_family}', sans-serif;
        }

        body {
          font-size: #{text_font_size}rem;
        }
      CSS
    end

    def header_font_family_styles
      return '' if current_theme_or_preview.preferred_header_font_family.blank?

      font_family = current_theme_or_preview.preferred_header_font_family

      <<~CSS
        h1, h2, h3, h4, h5, h6 {
          font-family: '#{font_family}', sans-serif;
        }
      CSS
    end

    def google_fonts_link_tag
      fonts = [current_theme_or_preview.preferred_font_family, current_theme_or_preview.preferred_header_font_family].compact_blank.uniq

      return if fonts.blank?

      font_weights = (200..700).step(100).to_a

      imports = fonts.map do |font|
        "family=#{font.split.join('+')}:wght@#{font_weights.join(';')}"
      end.compact.join('&')

      return if imports.blank?
      return if Rails.env.test?

      stylesheet_link_tag "https://fonts.googleapis.com/css2?#{imports}&display=swap"
    end

    def font_styles
      <<~CSS.html_safe
        #{normal_font_family_styles}
        #{header_font_family_styles}
      CSS
    end
  end
end
