module Spree
  class TaxCategory < Spree::Base
    acts_as_paranoid
    validates :name, presence: true, uniqueness: { scope: :deleted_at, allow_blank: true }

    has_many :tax_rates, dependent: :destroy, inverse_of: :tax_category

    before_save :set_default_category

    def set_default_category
      #set existing default tax category to false if this one has been marked as default

      if is_default && tax_category = self.class.where(is_default: true).first
        unless tax_category == self
          tax_category.update_columns(
            is_default: false,
            updated_at: Time.now,
          )
        end
      end
    end
  end
end
