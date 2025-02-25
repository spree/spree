module Spree
  class ColorsPreviewStylesPresenter
    def initialize(colors)
      @colors = colors.compact_blank.map do |color|
        case color
        when String
          color_name = CGI.unescapeHTML(color.strip)

          { name: color_name, filter_name: color_name }
        when Hash
          color_name = CGI.unescapeHTML(color[:name].strip)
          filter_name = color[:filter_name].present? ? CGI.unescapeHTML(color[:filter_name].strip) : color_name

          { name: color_name, filter_name: filter_name }
        end
      end
    end

    def to_s
      @to_s ||= if colors.any?
                  css = ['<style>']

                  colors.each do |color|
                    css_color = css_colors_hash[color[:filter_name]] || color[:filter_name].gsub(' ', '')
                    color_name = color[:name]
                    css << <<~CSS
                       @supports(background: #{css_color}) {
                        .color-input[value="#{color_name}"] ~ .label-container .color-preview,
                        [data-color="#{color_name}"] .color-preview {
                          background: #{css_color};
                          display: inline-flex;
                        }
                        .color-input[value="#{color_name}"] ~ .label-container .color-label,
                        [data-color="#{color_name}"] .color-label {
                          display: none;
                        }
                      }
                    CSS
                  end

                  css << '</style>'

                  css.join("\n")
                end
    end

    private

    attr_reader :colors

    def css_colors_hash
      @css_colors_hash ||= begin
        colors_hash = {}

        colors.each do |color|
          color_name = color[:filter_name]
          multi_colors = Spree::ColorNames.split_by_color_name(color_name)
          hex_colors = multi_colors.map(&method(:find_color)).compact

          if hex_colors.any?
            colors_hash[color_name] = generate_css_color(hex_colors)
          elsif (subcolors = color_name.split.compact) && subcolors.length > 1
            subcolors = subcolors.map(&method(:find_color)).compact
            colors_hash[color_name] = generate_css_color(subcolors)
          end
        end

        colors_hash
      end
    end

    def generate_css_color(hex_colors)
      if hex_colors.length > 1
        "linear-gradient(to right, #{hex_colors.join(', ')})"
      elsif hex_colors.length == 1
        hex_colors.first
      end
    end

    def find_color(color)
      Spree::ColorNames.find_by_name(color)&.dig('hex')
    end
  end
end
