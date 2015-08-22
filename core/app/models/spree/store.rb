module Spree
  class Store < Spree::Base
    validates :code, presence: true, uniqueness: { allow_blank: true }
    validates :name, presence: true
    validates :url, presence: true
    validates :mail_from_address, presence: true
    validates :default, uniqueness: { if: :default? }

    has_many :orders

    before_destroy :validate_not_default

    scope :by_url, lambda { |url| where("url like ?", "%#{url}%") }

    def self.current(domain = nil)
      current_store = domain ? Store.by_url(domain).first : nil
      current_store || Store.default
    end

    def self.default
      find_by(default: true) or fail 'Default store does not exist'
    end

    private

    def validate_not_default
      if default
        errors.add(:base, :cannot_destroy_default_store)
      end
    end
  end
end
