require_dependency 'spree/newsletter_subscriber/emails'

module Spree
  class NewsletterSubscriber < Spree.base_class
    include Spree::NewsletterSubscriber::Emails

    has_secure_token :verification_token

    belongs_to :user, optional: true, class_name: Spree.user_class.name

    validates :email, presence: true, uniqueness: true

    scope :verified, -> { where.not(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }

    def self.subscribe(email:, user: nil)
      Spree::Newsletter::Subscribe.new(email: email, user: user).call
    end

    def self.verify(verification_token)
      subscriber = find_by(verification_token: verification_token)
      return unless subscriber

      Spree::Newsletter::Verify.new(subscriber: subscriber).call
    end
  end
end