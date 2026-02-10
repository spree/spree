module Spree
  class UrlValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      unless url_valid?(value)
        record.errors.add(attribute, (options[:message] || ERROR_MESSAGE))
      end
    end

    private

    ERROR_MESSAGE = 'must be a valid URL'
    private_constant :ERROR_MESSAGE

    def url_valid?(url)
      uri = begin
        URI.parse(url)
      rescue URI::InvalidURIError
        return false
      end
      uri.host.present? && uri.is_a?(URI::HTTP)
    end
  end
end
