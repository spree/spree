module Spree
  class BuildLocalizedUrl
    prepend Spree::ServiceModule::Base

    LOCALE_REGEX = /^\/[A-Za-z]{2}\/|^\/[A-Za-z]{2}$/

    def call(url:, locale:, default_locale: nil)
      run :initialize_url_object
      run :generate_new_path
      run :build_url
    end

    protected

    def initialize_url_object(url:, locale:, default_locale:)
      success(url: URI(url), locale: locale, default_locale: default_locale)
    end

    def generate_new_path(url:, locale:, default_locale:)
      match = url.path.match(LOCALE_REGEX)[0].gsub('/', '') if url.path.match(LOCALE_REGEX)

      # we've found previously used locale in the URL, so we need to replace it
      # or if it's the default store locale remove it completely

      new_path = if default_locale.present? && default_locale.to_s == locale.to_s
                   match.present? ? url.path.gsub(LOCALE_REGEX, '/') : url.path
                 else
                   match.present? ? url.path.gsub(LOCALE_REGEX, "/#{locale}/") : "/#{locale}#{url.path}"
                 end
      success(url: url, path: new_path.chomp('/').gsub('//', '/'))
    end

    def build_url(url:, path:)
      builder_class = url.scheme == 'http' ? URI::HTTP : URI::HTTPS
      localized_url = builder_class.build(host: url.host, port: url.port, path: path, query: url.query).to_s
      success(localized_url)
    end
  end
end
