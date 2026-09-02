module Spree
  module CSV
    class NewsletterSubscriberPresenter
      include Spree::CSV::CustomFieldsHelper

      HEADERS = [
        'Email',
        'Customer Name',
        'Customer ID',
        'Verified',
        'Verified At',
        'Created At',
        'Updated At'
      ].freeze

      def initialize(newsletter_subscriber, store)
        @newsletter_subscriber = newsletter_subscriber
        @store = store
      end

      attr_accessor :newsletter_subscriber, :store

      def call
        csv = [
          newsletter_subscriber.email,
          newsletter_subscriber.customer&.full_name,
          newsletter_subscriber.customer_id,
          newsletter_subscriber.verified? ? Spree.t(:say_yes) : Spree.t(:say_no),
          newsletter_subscriber.verified_at,
          newsletter_subscriber.created_at,
          newsletter_subscriber.updated_at
        ]

        csv += custom_fields_for_csv(newsletter_subscriber, store)

        csv
      end
    end
  end
end
