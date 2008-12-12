require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

include Admin::ProductsHelper 
include Admin::BaseHelper 

describe '/admin/products/edit' do

  
  before(:each) do
    @product = Product.new(:name => 'Delicious Cows', :permalink => 'delicious-cows', :available_on => 2.days.ago,
                           :description => 'Cows are delicious!', :master_price => 45.00, :sku => 'DEL-COW-1', :on_hand => 99,
                           :variants => [Variant.new] 
    )
    assigns[:product] = @product
    
    template.stub!(:object_url).and_return(admin_product_url(@product))
    template.stub!(:collection_url).and_return('')

    assigns[:product_admin_tabs] = []
    
    @test_shipping = ShippingCategory.new(:name => "Test Shipping")
    @test_shipping.stub!(:id).and_return(1)
    assigns[:shipping_categories] = [@test_shipping]
    
    @test_tax = TaxCategory.new(:name => "Test Tax")
    @test_tax.stub!(:id).and_return(2)
    assigns[:tax_categories] = [@test_tax]
    
    @additional_fields =  [
        {:name => 'Weight'},
        {:name => 'Height', :only => [:product, :variant], :format => "%.2f"},
        {:name => 'Width', :only => [:variant], :format => "%.2f"},
        {:name => 'Depth', :only => [:variant], :populate => [:line_item]}
      ]
  end

  it "should display the standard edit form" do
    render '/admin/products/edit'
    
    response.should have_tag('form[method=?][action=?]', 'post', admin_product_url(@product)) do
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_name', @product.name)
      with_tag("textarea[id=?]", 'product_description', :text => @product.description)
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_master_price', @product.master_price)
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_available_on', CalendarDateSelect.format_date(@product.available_on))
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_sku', @product.sku)
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_on_hand', @product.on_hand)
      
      with_tag("select[id=?]", 'product_shipping_category_id') do
        with_tag("option[value=?]", '')
        with_tag("option[value=?]", @test_shipping.id, :text => @test_shipping.name)
      end
      
      with_tag("select[id=?]", 'product_tax_category_id') do
        with_tag("option[value=?]", '')
        with_tag("option[value=?]", @test_tax.id, :text => @test_tax.name)
      end
      
      with_tag("span[id=?]", 'new-img-link') do
        with_tag("a")
      end
      
      with_tag("input[type=?]", 'submit')
    end
  end
  
  
  it "should display additional fields when additional_fields is populated" do
    Variant.stub!(:additional_fields).and_return(@additional_fields)
     
    #only stub these two methods because they are the only ones configured
    #to be added to the products edit form
    @product.stub!(:weight).and_return('1200')
    @product.stub!(:height).and_return('99')
 
    render '/admin/products/edit'
    
    response.should have_tag('form[method=?][action=?]', 'post', admin_product_url(@product)) do     
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_weight', '1200')
      with_tag("input[type=?][id=?][value=?]", 'text', 'product_height', '99.00') #format present
      
      without_tag("input[type=?][id=?]", 'text', 'product_width') #ensure that variant only width field does not appear
    end
    
  end

end


