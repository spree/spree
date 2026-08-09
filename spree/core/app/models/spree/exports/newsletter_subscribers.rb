module Spree
  module Exports
    class NewsletterSubscribers < Spree::Export
      def self.required_scope
        :customers
      end

      def scope_includes
        [:user, { custom_fields: :custom_field_definition }]
      end

      def csv_headers
        Spree::CSV::NewsletterSubscriberPresenter::HEADERS + custom_fields_headers
      end
    end
  end
end
