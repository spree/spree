module Spree
  class Store < Spree::Base

    validates :code, presence: true, uniqueness: true
    validates :name, presence: true
    validates :url, presence: true
    validates :mail_from_address, presence: true

    before_create :ensure_default_exists_and_is_unique

    scope :by_url, lambda { |url| where("url like ?", "%#{url}%") }

    def self.default
      where(default: true).first || new
    end

    def self.cached_default
      @cached_default ||= Store.default
    end

    private

    def ensure_default_exists_and_is_unique
      if default
        Store.update_all(default: false)
      else
        self.default = true
      end
    end

  end
end
