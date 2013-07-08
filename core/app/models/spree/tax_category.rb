module Spree
  class TaxCategory < ActiveRecord::Base
    acts_as_paranoid
    validates :name, presence: true, uniqueness: { scope: :deleted_at }

    has_many :tax_rates, dependent: :destroy

    attr_accessible :name, :description, :is_default

    before_save :set_default_category

    def set_default_category
      #set existing default tax category to false if this one has been marked as default

      if is_default && tax_category = self.class.where(is_default: true).first
        tax_category.update_column(:is_default, false) unless tax_category == self
      end
    end
  end
end
