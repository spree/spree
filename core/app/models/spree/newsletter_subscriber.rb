module Spree
  class NewsletterSubscriber < Spree.base_class
    has_secure_token :verification_token

    belongs_to :user, optional: true, class_name: Spree.user_class.name

    validates :email,
              presence: true,
              format: { with: URI::MailTo::EMAIL_REGEXP },
              uniqueness: { case_sensitive: false }

    scope :verified, -> { where.not(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }

    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

    def verified?
      verified_at.present?
    end

    def self.subscribe(email:, user: nil)
      raise NotImplementedError
    end

    def self.verify(verification_token)
      subscriber = find_by(verification_token: verification_token)
      return unless subscriber

      raise NotImplementedError
    end
  end
end
