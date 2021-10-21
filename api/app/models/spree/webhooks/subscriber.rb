module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      validates :url, 'spree/url': true, presence: true

      validate :check_uri_path

      scope :active, -> { where(active: true) }

      private

      def check_uri_path
        uri = begin
                URI.parse(url)
              rescue URI::InvalidURIError
                return false
              end

        errors.add(:url, 'the URL must have a path') if uri.blank? || uri.path.blank?
      end
    end
  end
end
