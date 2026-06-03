module Spree
  class NewsletterSubscriber < Spree.base_class
    has_prefix_id :sub

    include Spree::Metafields
    include Spree::SingleStoreResource

    publishes_lifecycle_events

    has_secure_token :verification_token

    generates_token_for :unsubscribe do
      email
    end

    #
    # Associations
    #
    belongs_to :user, optional: true, class_name: Spree.user_class&.name
    belongs_to :store, class_name: 'Spree::Store', required: true

    #
    # Validations
    #
    validates :email,
              presence: true,
              format: { with: URI::MailTo::EMAIL_REGEXP },
              uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope + [:store_id] }

    #
    # Scopes
    #
    scope :verified, -> { where.not(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }

    #
    # Callbacks
    #
    before_validation :set_store, unless: :store_id?
    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

    #
    # Ransack filtering
    #
    self.whitelisted_ransackable_attributes = %w[email verified_at]
    self.whitelisted_ransackable_scopes = %w[verified unverified]
    
    def accepts_email_marketing
      return user.accepts_email_marketing if user.present?

      verified?
    end

    def verified?
      verified_at.present?
    end

    def to_csv(_store = nil)
      Spree::CSV::NewsletterSubscriberPresenter.new(self).call
    end

    def self.subscribe(email:, user: nil, store: nil, redirect_url: nil)
      store ||= Spree::Current.store

      Spree::Newsletter::Subscribe.new(
        email: email,
        current_user: user,
        current_store: store,
        redirect_url: redirect_url
      ).call
    end

    def self.verify(token:)
      subscriber = unverified.find_by!(verification_token: token)

      Spree::Newsletter::Verify.new(subscriber: subscriber).call
    end

    private

    def set_store
      self.store ||= Spree::Current.store
    end
  end
end
