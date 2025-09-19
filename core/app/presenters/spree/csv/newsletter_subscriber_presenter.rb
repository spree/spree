module Spree
  module CSV
    class NewsletterSubscriberPresenter
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
        [
          newsletter_subscriber.email,
          newsletter_subscriber.user&.full_name,
          newsletter_subscriber.user_id,
          newsletter_subscriber.verified? ? Spree.t(:say_yes) : Spree.t(:say_no),
          newsletter_subscriber.verified_at,
          newsletter_subscriber.created_at,
          newsletter_subscriber.updated_at
        ]
      end
    end
  end
end
