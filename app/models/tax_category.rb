class TaxCategory < ActiveRecord::Base
  validates :name, :presence => true, :uniqueness => true

  has_many :tax_rates

  def before_save
    #set existing default tax category to false if this one has been marked as default

    if is_default && tax_category = TaxCategory.find(:first, :conditions => {:is_default => true})
      tax_category.update_attribute(:is_default, false)
    end
  end
end
