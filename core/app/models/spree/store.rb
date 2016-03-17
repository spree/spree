module Spree
  class Store < Spree::Base
    has_many :orders, class_name: "Spree::Order"

    with_options presence: true do
      validates :code, uniqueness: { allow_blank: true }
      validates :name, :url, :mail_from_address
    end

    before_save :ensure_default_exists_and_is_unique
    before_destroy :validate_not_default

    scope :by_url, lambda { |url| where("url like ?", "%#{url}%") }

    before_save :clear_cache
    after_destroy :clear_cache

    def self.current(domain = nil)
      current_store = domain ? Store.by_url(domain).first : nil
      current_store || Store.default
    end

    def self.default
      Rails.cache.fetch("default_store") do
        find_or_initialize_by(default: true)
      end
    end

    def self.has_default?
      where(default: true).any?
    end

    private

    def ensure_default_exists_and_is_unique
      if default?
        remove_previous_default
      elsif !self.class.has_default?
        self.default = true
      end
    end

    def validate_not_default
      if default?
        errors.add(:base, :cannot_destroy_default_store)
        false
      end
    end

    def clear_cache
      Rails.cache.delete("default_store")
    end

    def remove_previous_default
      Store.where.not(id: id).update_all(default: false)
    end
  end
end
