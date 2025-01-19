module Spree
  class CustomDomain < Spree::Base
    include Spree::SingleStoreResource
    include Spree::Metadata

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :custom_domains
    validates :url, presence: true, uniqueness: true, format: {
      with: %r{[a-z][a-z0-9-]*[a-z0-9]}i
    }, length: { in: 1..63 }
    validate :url_is_valid

    after_save :ensure_has_one_default
    after_validation :ensure_default, on: :create

    def can_be_deleted?
      true
    end

    def url_is_valid
      parts = url.split('.')

      errors.add(:url, 'use domain or subdomain') if (parts[0] != 'www' && parts.size > 3) || (parts[0] == 'www' && parts.size > 4) || parts.size < 2
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
  end
end
