module Spree
  module Emails
    # How a store's customer emails look: its colors and font over the
    # defaults the shipped layout was designed with. Templates read it as
    # `store.branding`, so it outlives any edit or revert of a template.
    class Branding
      include ActiveModel::Model
      include ActiveModel::Attributes

      COLOR_FORMAT = /\A#\h{6}\z/

      # Email-safe fonts, with fallback stacks for clients that do not load
      # web fonts. Family names stay unquoted: templates escape what they print.
      FONTS = {
        'inter' => { family: 'Inter, Helvetica, Arial, sans-serif', heading_family: 'Geist, Inter, Helvetica, Arial, sans-serif' },
        'system' => { family: '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif' },
        'helvetica' => { family: 'Helvetica, Arial, sans-serif' },
        'georgia' => { family: 'Georgia, Times New Roman, Times, serif' },
        'roboto' => { family: 'Roboto, Helvetica, Arial, sans-serif', url: 'https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700' },
        'lato' => { family: 'Lato, Helvetica, Arial, sans-serif', url: 'https://fonts.googleapis.com/css2?family=Lato:wght@400;700' },
        'merriweather' => { family: 'Merriweather, Georgia, serif', url: 'https://fonts.googleapis.com/css2?family=Merriweather:wght@400;700' }
      }.freeze

      DEFAULT_FONT = 'inter'.freeze
      DEFAULT_COLORS = {
        background_color: '#FFFFFF', card_color: '#F6F6F6', text_color: '#726A6A', heading_color: '#332C2C'
      }.freeze
      COLORS = %i[accent_color background_color card_color text_color heading_color].freeze

      COLORS.each { |color| attribute color, :string }
      attribute :font, :string

      validates(*COLORS, format: { with: COLOR_FORMAT }, allow_blank: true)
      validates :font, inclusion: { in: FONTS.keys }, allow_blank: true

      # What templates read as `store.branding`. A value that is not a color
      # or a known font falls back to the default, so nothing else ever reaches
      # an email's CSS, unsaved preview values included.
      #
      # @return [Hash{String => String, nil}]
      def to_h
        accent = color(:accent_color)
        typeface_key = FONTS.key?(font) ? font : DEFAULT_FONT
        typeface = FONTS[typeface_key]
        colors = DEFAULT_COLORS.to_h { |name, default| [name, color(name) || default] }

        {
          **colors,
          accent_color: accent,
          link_color: accent || colors[:heading_color],
          # Without an accent, buttons keep the outlined look the layout ships with.
          button_color: accent || '#FFFFFF',
          button_text_color: accent ? readable_text_on(accent) : '#1F2222',
          button_border: accent ? 'none' : '1px solid #E8E9E9',
          font: typeface_key,
          font_family: typeface[:family],
          heading_font_family: typeface[:heading_family] || typeface[:family],
          font_url: typeface[:url]
        }.stringify_keys
      end

      private

      def color(name)
        value = public_send(name).to_s
        value.upcase if value.match?(COLOR_FORMAT)
      end

      # Black or white, whichever reads better on the color (WCAG relative luminance).
      def readable_text_on(hex)
        red, green, blue = hex.delete('#').scan(/../).map do |channel|
          value = channel.to_i(16) / 255.0
          value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
        end
        luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        luminance > 0.179 ? '#000000' : '#FFFFFF'
      end
    end
  end
end
