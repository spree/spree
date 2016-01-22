module Spree
  class TaxCategory < Spree::Base
    acts_as_paranoid
    validates :name, presence: true, uniqueness: { scope: :deleted_at, allow_blank: true }

    has_many :tax_rates, dependent: :destroy, inverse_of: :tax_category

    before_save :set_default_category

    before_save :clear_cache

    def set_default_category
      #set existing default tax category to false if this one has been marked as default

      if is_default && tax_category = self.class.where(is_default: true).where.not(id: id).first
        tax_category.update_columns(is_default: false, updated_at: Time.current)
      end
    end

    def self.default
      Rails.cache.fetch("#{Rails.application.class.parent_name.underscore}_default_tax_category") do
        where(is_default: true).first
      end
    end

    private
    def clear_cache
      Rails.cache.delete("#{Rails.application.class.parent_name.underscore}_default_tax_category")
    end
  end
end
