module Spree
  module Admin
    module PageBuilderHelper
      def system_fonts_list
        ['Sans-serif', 'Serif', 'Mono']
      end

      def google_fonts_list
        ['Abel', 'Abril Fatface', 'Alegreya', 'Alegreya Sans', 'Alice', 'Amiri', 'Anonymous Pro', 'Arapey', 'Archivo', 'Archivo Narrow',
         'Arimo', 'Armata', 'Arvo', 'Asap', 'Assistant', 'Asul', 'Bitter', 'Cabin', 'Cardo', 'Catamaran', 'Chivo', 'Cormorant',
         'Crimson Text', 'DM Sans', 'Domine', 'Dosis', 'Eczar', 'Figtree', 'Fira Sans', 'Fjalla One', 'Glegoo', 'IBM Plex Sans', 'Inconsolata',
         'Inknut Antiqua', 'Inter', 'Josefin Sans', 'Josefin Slab', 'Kalam', 'Karla', 'Kreon', 'Lato', 'Libre Baskerville',
         'Libre Franklin', 'Lobster', 'Lobster Two', 'Lora', 'Maven Pro', 'Megrim', 'Merriweather Sans', 'Montserrat',
         'Mouse Memoirs', 'Muli', 'Neuton', 'News Cycle', 'Nobile', 'Noticia Text', 'Noto Serif', 'Nunito', 'Nunito Sans',
         'Old Standard TT', 'Open Sans', 'Oswald', 'Ovo', 'Oxygen', 'PT Mono', 'PT Sans', 'PT Sans Narrow', 'PT Serif',
         'Pacifico', 'Playball', 'Playfair Display', 'Poppins', 'Prata', 'Prompt', 'Quattrocento', 'Quattrocento Sans',
         'Questrial', 'Quicksand', 'Rajdhani', 'Raleway', 'Righteous', 'Roboto', 'Roboto Condensed', 'Roboto Mono', 'Roboto Slab',
         'Rubik', 'Shadows Into Light', 'Slabo 13px', 'Slabo 27px', 'Smooch', 'Source Code Pro', 'Source Sans Pro', 'Space Mono',
         'Syne', 'Tenor Sans', 'Tinos', 'Titillium Web', 'Ubuntu', 'Unica One', 'Unna', 'Varela', 'Varela Round', 'Vidaloka',
         'Volkhov', 'Vollkorn', 'Work Sans']
      end

      def color_palettes
        [
          {
            primary_color: '#1e4bd1',
            text_color: '#000000',
            border_color: '#d1d5db',
            button_text_color: '#ffffff',
            background_color: '#F9FAFB'
          },
          {
            primary_color: '#e63946',
            text_color: '#1d3557',
            border_color: '#a8dadc',
            button_text_color: '#ffffff',
            background_color: '#f1faee'
          },
          {
            primary_color: '#264653',
            text_color: '#060C0E',
            border_color: '#2a9d8f',
            button_text_color: '#ffffff',
            background_color: '#e9c46a'
          },
          {
            primary_color: '#606c38',
            text_color: '#283618',
            border_color: '#dda15e',
            button_text_color: '#ffffff',
            background_color: '#fefae0'
          },
          {
            primary_color: '#FF961F',
            text_color: '#023047',
            border_color: '#219EBC',
            button_text_color: '#FFEEDA',
            background_color: '#DEF0F7'
          },
          {
            primary_color: '#181CF1',
            text_color: '#011627',
            border_color: '#7678ED',
            button_text_color: '#FFFFFF',
            background_color: '#FFF5D6'
          }
        ]
      end

      def color_palette_active?(color_palette)
        @theme_preview&.primary_color&.downcase == color_palette[:primary_color].downcase &&
          @theme_preview&.text_color&.downcase == color_palette[:text_color].downcase &&
          @theme_preview&.border_color&.downcase == color_palette[:border_color].downcase &&
          @theme_preview&.button_text_color&.downcase == color_palette[:button_text_color].downcase &&
          @theme_preview&.background_color&.downcase == color_palette[:background_color].downcase
      end

      def all_fonts_options
        @all_fonts_options ||= system_fonts_list + google_fonts_list
      end

      def all_linkable_pages
        @all_linkable_pages ||= Spree::Page.
                                linkable.
                                without_previews.
                                where(pageable: [@theme, current_store]).
                                map { |page| [page.display_name, page.id] }
      end

      def all_linkable_policies
        @all_linkable_policies = [
          current_store.customer_privacy_policy,
          current_store.customer_terms_of_service,
          current_store.customer_returns_policy,
          current_store.customer_shipping_policy
        ].compact.map { |policy| [policy.name.humanize, policy.id] }
      end

      def refresh_theme_preview(section = nil, block = nil)
        reload_params = section.present? ? "{ frame: 'section-#{section.id}' }" : "{ action: 'replace' }"

        editor_id = if block.present?
                      "block-#{block.id}"
                    elsif section.present?
                      "section-#{section.id}"
                    end

        turbo_stream.replace :iframe_preview_scripts do
          turbo_frame_tag :iframe_preview_scripts do
            javascript_tag do
              raw <<~JS
                document.getElementById('page-builder-preview').contentWindow.window.Turbo.visit(
                  document.getElementById('page-builder').dataset.pageBuilderPreviewUrlValue + '&editor_id=#{editor_id}',
                  #{reload_params}
                )
              JS
            end
          end
        end
      end

      def page_preview_url
        preview_url = @page.preview_url(@theme_preview, @page_preview)
        return if preview_url.blank?

        "#{preview_url}&page_builder=true"
      end
    end
  end
end
