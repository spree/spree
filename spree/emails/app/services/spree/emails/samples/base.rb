module Spree
  module Emails
    module Samples
      # Builds what an email's template receives, for previewing a template
      # and checking it before it is published: from the store's most recent
      # matching record, or one the merchant picks. Values that would carry a
      # token (reset, invitation, download links) are always placeholders.
      class Base
        # @return [String, nil] the kind of record the merchant can pick
        #   ("order", "order_group", "fulfillment", "return"), or nil when the
        #   email needs none
        def self.record_type
          nil
        end

        attr_reader :store, :record_id

        # @param store [Spree::Store]
        # @param record_id [String, nil] a prefixed id of the record to preview with
        def initialize(store:, record_id: nil)
          @store = store
          @record_id = record_id.presence
        end

        # @return [Hash] the template's variables, before `store` and `locale` are added
        def variables
          raise NotImplementedError
        end

        # @return [String] the currency the email's amounts are in
        def currency
          self.class.record_type ? record.currency : store.default_currency
        end

        protected

        def record
          @record ||= if record_id
                        records.find_by_prefix_id!(record_id)
                      else
                        records.first || raise(Spree::EmailTemplates::NoSampleRecord, Spree.t('email_templates.no_sample_record', record: self.class.record_type.to_s.humanize.downcase))
                      end
        end

        # Every lookup goes through the store, so another store's record never answers.
        def records
          raise NotImplementedError
        end

        def data(object, serializer)
          Spree::Emails::TemplateData.call(object, serializer, store: store, currency: currency)
        end

        def placeholder_url(path)
          "#{store.storefront_url.to_s.chomp('/')}/#{path}?token=preview"
        end
      end
    end
  end
end
