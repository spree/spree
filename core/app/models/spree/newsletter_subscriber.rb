module Spree
  class NewsletterSubscriber < ApplicationRecord
    has_secure_token :verification_token

    belongs_to :user, optional: true

    validates :email, presence: true, uniqueness: true

    scope :verified, -> { where.not(verified_at: nil) }

    def self.subscribe(email: email, user: nil)
      Spree::Newselleter::Subscribe.new(email: email, user: current_user).call
    end

    def self.verify(verification_token)
      subscriber = find_by(verification_token: verification_token)
      return unless subscriber

      Spree::Newselleter::Verify.new(subscriber: subscriber).call
    end
  end
end