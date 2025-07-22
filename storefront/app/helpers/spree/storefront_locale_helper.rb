module Spree
  module StorefrontLocaleHelper
    # Returns the currently selected locale.
    #
    # @return [String] The currently selected locale
    def current_locale
      @current_locale ||= if user_locale?
                            try_spree_current_user.selected_locale
                          elsif params_locale?
                            params[:locale]
                          elsif header_locale?
                            header_locale
                          end
    ensure
      @current_locale ||= default_locale
    end

    def header_locale?
      header_locale.present?
    end

    # Taken from rack-contrib
    # https://github.com/rack/rack-contrib/blob/main/lib/rack/contrib/locale.rb#L58
    def header_locale
      header = request.env['HTTP_ACCEPT_LANGUAGE']

      return if header.nil?

      locales = header.gsub(/\s+/, '').split(",").map do |language_tag|
        locale, quality = language_tag.split(/;q=/i)
        quality = quality ? quality.to_f : 1.0
        [locale, quality]
      end
      locales = locales.
                reject { |(locale, quality)| locale == '*' || quality.zero? }.
                sort_by { |(_, quality)| quality }.
                map(&:first)

      locale_from_header = locales.reverse.find { |locale| supported_locale?(locale) }
      locale_from_header ||= locales.reverse.find { |locale| supported_locale?(locale.first(2)) }&.first(2)

      locale_from_header
    end
  end
end
