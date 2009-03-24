require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe TaxCategory do
  before(:each) do
    @tax_category = TaxCategory.new :name => 'dummy'
  end

  it "should be valid" do
    @tax_category.should be_valid
  end
end
