module Spree
  module CSV
    class NewsletterSubscriberPresenter
      include Spree::CSV::MetafieldsHelper

      HEADERS = [
        'Email',
        'Customer Name',
        'Customer ID',
        'Verified',
        'Verified At',
        'Created At',
        'Updated At'
      ].freeze

      def initialize(newsletter_subscriber)
        @newsletter_subscriber = newsletter_subscriber
      end

      attr_accessor :newsletter_subscriber

      def call
        csv = [
          newsletter_subscriber.email,
          newsletter_subscriber.user&.full_name,
          newsletter_subscriber.user_id,
          newsletter_subscriber.verified? ? Spree.t(:say_yes) : Spree.t(:say_no),
          newsletter_subscriber.verified_at,
          newsletter_subscriber.created_at,
          newsletter_subscriber.updated_at
        ]

        csv += metafields_for_csv(newsletter_subscriber)

        csv
      end
    end
  end
end
