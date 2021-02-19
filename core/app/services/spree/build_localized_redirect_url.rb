require 'uri'

module Spree
  class BuildLocalizedRedirectUrl
    prepend Spree::ServiceModule::Base

    LOCALE_REGEX = /^\/[A-Za-z]{2}\/|^\/[A-Za-z]{2}-[A-Za-z]{2}\/|^\/[A-Za-z]{2}$|^\/[A-Za-z]{2}-[A-Za-z]{2}$/.freeze

    SUPPORTED_PATHS_REGEX = /\/(products|t\/|cart|checkout|addresses|content)/.freeze

    # rubocop:disable Lint/UnusedMethodArgument
    def call(url:, locale:, default_locale: nil)
      run :initialize_url_object
      run :generate_new_path
      run :append_locale_param
      run :build_url
    end
    # rubocop:enable Lint/UnusedMethodArgument

    protected

    def initialize_url_object(url:, locale:, default_locale:)
      success(
        url: URI(url),
        locale: locale,
        default_locale_supplied: default_locale_supplied?(locale, default_locale)
      )
    end

    def generate_new_path(url:, locale:, default_locale_supplied:)
      unless supported_path?(url.path)
        return success(
          url: url,
          locale: locale,
          path: cleanup_path(url.path),
          default_locale_supplied: default_locale_supplied,
          locale_added_to_path: false
        )
      end

      new_path = if default_locale_supplied
                   maches_locale_regex?(url.path) ? url.path.gsub(LOCALE_REGEX, '/') : url.path
                 else
                   maches_locale_regex?(url.path) ? url.path.gsub(LOCALE_REGEX, "/#{locale}/") : "/#{locale}#{url.path}"
                 end

      success(
        url: url,
        locale: locale,
        path: cleanup_path(new_path),
        default_locale_supplied: default_locale_supplied,
        locale_added_to_path: true
      )
    end

    def append_locale_param(url:, locale:, path:, default_locale_supplied:, locale_added_to_path:)
      return success(url: url, path: path, query: url.query) if locale_added_to_path

      query_params = Rack::Utils.parse_nested_query(url.query)

      if default_locale_supplied
        query_params.delete('locale')
      else
        query_params.merge!('locale' => locale)
      end

      query_string = query_params.any? ? query_params.to_query : nil

      success(url: url, path: path, query: query_string)
    end

    def build_url(url:, path:, query:)
      localized_url = builder_class(url).build(host: url.host, port: url.port, path: path, query: query).to_s
      success(localized_url)
    end

    private

    def supported_path?(path)
      return true if path.blank? || path == '/' || maches_locale_regex?(path)

      path.match(SUPPORTED_PATHS_REGEX)
    end

    def maches_locale_regex?(path)
      path.match(LOCALE_REGEX)[0].gsub('/', '') if path.match(LOCALE_REGEX)
    end

    def default_locale_supplied?(locale, default_locale)
      default_locale.present? && default_locale.to_s == locale.to_s
    end

    def cleanup_path(path)
      path.chomp('/').gsub('//', '/')
    end

    def builder_class(url)
      url.scheme == 'http' ? URI::HTTP : URI::HTTPS
    end
  end
end
