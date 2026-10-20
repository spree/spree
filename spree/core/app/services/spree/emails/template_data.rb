module Spree
  module Emails
    # Turns a record into the JSON an email template reads: the serializer's
    # output, the same data a renderer outside Ruby would receive. Shared by
    # mailers and by the sample data the template editor previews with.
    # Download links and other bearer tokens stay out of it.
    module TemplateData
      # @param object [Object, nil] the record
      # @param serializer [Class] an email serializer
      # @param store [Spree::Store]
      # @param currency [String, nil] defaults to the store's
      # @param params [Hash] serializer params over the defaults
      # @return [Hash, nil]
      def self.call(object, serializer, store:, currency: nil, **params)
        return if object.nil?

        params = { store: store, currency: currency || store.default_currency, locale: I18n.locale.to_s,
                   storefront_url: store.storefront_url.to_s.chomp('/'), hide_credentials: true }.merge(params)
        JSON.parse(serializer.new(object, params: params).serialize)
      end
    end
  end
end
