module Spree
  class TaxCategory < ActiveRecord::Base
    validates :name, :presence => true, :uniqueness => true
    has_many :tax_rates, :dependent => :destroy
  end
end
