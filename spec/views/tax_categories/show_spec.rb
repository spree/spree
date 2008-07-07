require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/tax_categories/show.html.erb" do
  include TaxCategoriesHelper
  
  before(:each) do
    @tax_category = mock_model(TaxCategory)

    assigns[:tax_category] = @tax_category

    template.stub!(:edit_object_url).and_return(edit_tax_category_path(@tax_category)) 
    template.stub!(:collection_url).and_return(tax_categories_path) 
  end

  it "should render attributes in <p>" do
    render "/tax_categories/show.html.erb"
  end
end

