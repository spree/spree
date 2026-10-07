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

        # @return [Array<String>] the permission keys a caller needs to see this
        #   sample, since it shows a real record's data
        def self.required_permissions
          record_type ? %w[read_orders] : []
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

        # @param limit [Integer]
        # @return [Array<Spree::EmailTemplates::SampleRecord>] the store's latest
        #   records the email can be previewed with; empty when it needs none
        def recent_records(limit: 5)
          return [] unless self.class.record_type

          records.limit(limit).map do |record|
            Spree::EmailTemplates::SampleRecord.new(
              id: record.prefixed_id, label: record.try(:number).presence || record.prefixed_id, created_at: record.created_at
            )
          end
        end

        # @return [String] the currency the email's amounts are in
        def currency
          (self.class.record_type && record.try(:currency)).presence || store.default_currency
        end

        protected

        def record
          @record ||= if record_id
                        records.find_by_prefix_id!(record_id)
                      else
                        records.first || raise(Spree::EmailTemplates::NoSampleRecord, I18n.t('spree.email_templates.no_sample_record', record: self.class.record_type.to_s.humanize.downcase))
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
