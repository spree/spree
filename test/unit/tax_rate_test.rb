require 'test_helper'

class TaxRateTest < Test::Unit::TestCase  
  should_belong_to :zone
  should_belong_to :tax_category
  #should_validate_presence_of :tax_type, :message => /should be Sales Tax and Vat/
  should_validate_presence_of :amount
  should_validate_numericality_of :amount
end