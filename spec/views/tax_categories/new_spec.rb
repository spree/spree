require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/tax_categories/new.html.erb" do
  include TaxCategoriesHelper
  
  before(:each) do
    @tax_category = mock_model(TaxCategory)
    @tax_category.stub!(:new_record?).and_return(true)
    assigns[:tax_category] = @tax_category


    template.stub!(:object_url).and_return(tax_category_path(@tax_category)) 
    template.stub!(:collection_url).and_return(tax_categories_path) 
  end

  it "should render new form" do
    render "/tax_categories/new.html.erb"
    
    response.should have_tag("form[action=?][method=post]", tax_categories_path) do
    end
  end
end


