module Spree
  class Store < Spree::Base
    has_many :orders, class_name: 'Spree::Order'
    has_many :payment_methods, class_name: 'Spree::PaymentMethod'

    with_options presence: true do
      validates :name, :url, :mail_from_address
      validates :default_currency
    end

    before_save :ensure_default_exists_and_is_unique
    before_destroy :validate_not_default

    scope :by_url, ->(url) { where('url like ?', "%#{url}%") }

    after_commit :clear_cache

    def self.current(domain = nil)
      current_store = domain ? Store.by_url(domain).first : nil
      current_store || Store.default
    end

    def self.default
      Rails.cache.fetch('default_store') do
        where(default: true).first_or_initialize
      end
    end

    private

    def ensure_default_exists_and_is_unique
      if default
        Store.where.not(id: id).update_all(default: false)
      elsif Store.where(default: true).count.zero?
        self.default = true
      end
    end

    def validate_not_default
      if default
        errors.add(:base, :cannot_destroy_default_store)
        throw(:abort)
      end
    end

    def clear_cache
      Rails.cache.delete('default_store')
    end
  end
end
