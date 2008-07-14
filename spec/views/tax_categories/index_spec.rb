require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/tax_categories/index.html.erb" do
  include TaxCategoriesHelper
  
  before(:each) do
    tax_category_98 = mock_model(TaxCategory)
    tax_category_99 = mock_model(TaxCategory)

    assigns[:tax_categories] = [tax_category_98, tax_category_99]

    template.stub!(:object_url).and_return(tax_category_path(@tax_category)) 
    template.stub!(:new_object_url).and_return(new_tax_category_path) 
    template.stub!(:edit_object_url).and_return(edit_tax_category_path(@tax_category)) 
  end

  it "should render list of tax_categories" do
    render "admin/tax_categories/index"
  end
end
