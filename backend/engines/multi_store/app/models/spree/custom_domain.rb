module Spree
  class CustomDomain < Spree::Base
    has_prefix_id :domain

    include Spree::SingleStoreResource
    include Spree::Metafields
    include Spree::Metadata

    normalizes :url, with: ->(value) { value&.to_s&.squish&.presence }

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :custom_domains, touch: true

    #
    # Validations
    #
    validates :url, presence: true, uniqueness: true, format: {
      with: %r{\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z}i
    }, length: { in: 1..63 }
    validate :url_is_valid

    #
    # Callbacks
    #
    before_validation :sanitize_url
    after_save :ensure_has_one_default
    after_validation :ensure_default, on: :create

    def url_is_valid
      return if url.blank?
      parts = url.split('.')

      errors.add(:url, 'use domain or subdomain') if parts.size > 4 || parts.size < 2
    end

    def ensure_default
      self.default = store.custom_domains.count.zero?
    end

    def ensure_has_one_default
      store.custom_domains.where.not(id: id).update_all(default: false) if default?
    end

    def active?
      true
    end

    def name
      url
    end

    private

    # remove https:// and http:// from the url
    def sanitize_url
      self.url = url&.gsub(%r{https?://}, '')
    end
  end
end
