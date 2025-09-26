require_dependency 'spree/newsletter_subscriber/emails'

module Spree
  class NewsletterSubscriber < Spree.base_class
    include Spree::NewsletterSubscriber::Emails
    include Spree::Metafields

    has_secure_token :verification_token

    #
    # Associations
    #
    belongs_to :user, optional: true, class_name: Spree.user_class.name

    #
    # Validations
    #
    validates :email,
              presence: true,
              format: { with: URI::MailTo::EMAIL_REGEXP },
              uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope }

    #
    # Scopes
    #
    scope :verified, -> { where.not(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }

    #
    # Callbacks
    #
    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

    #
    # Ransack filtering
    #
    self.whitelisted_ransackable_attributes = %w[email verified_at]
    self.whitelisted_ransackable_scopes = %w[verified unverified]

    def verified?
      verified_at.present?
    end

    def to_csv(_store = nil)
      Spree::CSV::NewsletterSubscriberPresenter.new(self).call
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
