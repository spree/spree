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

    def self.current(domain = nil)
      current_store = domain ? Store.by_url(domain).first : nil
      current_store || Store.default
    end

    def self.default
      Rails.cache.fetch("default_store") do
        where(default: true).first || new
      end
    end

    private

    def ensure_default_exists_and_is_unique
      if default
        Store.where.not(id: id).each do |store|
          store.update_attribute(:default, false)
        end
      elsif Store.where(default: true).count.zero?
        self.default = true
      end
    end

    def validate_not_default
      if default
        errors.add(:base, :cannot_destroy_default_store)
      end
    end

    def clear_cache
      Rails.cache.delete("default_store")
    end
  end
end
