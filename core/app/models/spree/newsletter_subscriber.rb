require_dependency 'spree/newsletter_subscriber/emails'

module Spree
  class NewsletterSubscriber < Spree.base_class
    include Spree::NewsletterSubscriber::Emails

    has_secure_token :verification_token

    belongs_to :user, optional: true, class_name: Spree.user_class.name

    validates :email,
              presence: true,
              format: { with: URI::MailTo::EMAIL_REGEXP },
              uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope }

    scope :verified, -> { where.not(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }

    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

    def verified?
      verified_at.present?
    end

    def self.subscribe(email:, user: nil)
      Spree::Newsletter::Subscribe.new(email: email, user: user).call
    end

    def self.verify(token:)
      subscriber = unverified.find_by!(verification_token: token)

      Spree::Newsletter::Verify.new(subscriber: subscriber).call
    end
  end
end
