module Spree
  class Store < Spree::Base
    has_many :orders, class_name: "Spree::Order"

    with_options presence: true do
      validates :code, uniqueness: { allow_blank: true }
      validates :name, :url, :mail_from_address
    end

    before_destroy :validate_not_default

    scope :by_url, lambda { |url| where("url like ?", "%#{url}%") }

    include DefaultCacheable

    def self.current(domain = nil)
      current_store = domain ? Store.by_url(domain).first : nil
      current_store || Store.default
    end

    def self.default_query
      where(default: true).first || first || new
    end

    private

    def validate_not_default
      if default
        errors.add(:base, :cannot_destroy_default_store)
      end
    end
  end
end
