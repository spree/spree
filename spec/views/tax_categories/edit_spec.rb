require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/tax_categories/edit.html.erb" do
  include TaxCategoriesHelper
  
  before do
    @tax_category = mock_model(TaxCategory)
    assigns[:tax_category] = @tax_category

    template.should_receive(:object_url).twice.and_return(tax_category_path(@tax_category)) 
    template.should_receive(:collection_url).and_return(tax_categories_path) 
  end

  it "should render edit form" do
    render "/tax_categories/edit.html.erb"
    
    response.should have_tag("form[action=#{tax_category_path(@tax_category)}][method=post]") do
    end
  end
end


