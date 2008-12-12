require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

include Admin::ProductsHelper 
include Admin::BaseHelper

describe '/admin/variants/edit' do
  
  before(:each) do
    
    Admin::BaseHelper.class_eval do
    
      def t(string)
        string
      end
    end
    
    @product = Product.new(:name => 'Delicious Cows', :permalink => 'delicious-cows', :available_on => 2.days.ago,
                           :description => 'Cows are delicious!')
    @product.stub!(:id).and_return(99)
    
    @option_type = mock_model(OptionType)
    add_stubs(@option_type, :id => 11, :name => "cow-color", :presentation => "Color")
    
    @option_value = mock_model(OptionValue)
    add_stubs(@option_value, :id => 111, :option_type => @option_type, :name => 'Red', :position => 1, :presentation => "Red")
    
    @variant = mock_model(Variant)
    add_stubs(@variant, :sku => "DEL-COW-1A", :price => 49.99, :product => @product, :option_values => [@option_value], :on_hand => 9)
    @variant.errors.stub!(:on).and_return(false)
  
    assigns[:variant] = @variant
    assigns[:product] = @product
    
    template.stub!(:object_url).and_return('')
    template.stub!(:collection_url).and_return('')

    assigns[:product_admin_tabs] = []
        
    @additional_fields =  [
        {:name => 'Weight', :only => [:product]},
        {:name => 'Height', :only => [:product, :variant], :format => "%.2f"},
        {:name => 'Width', :only => [:variant], :format => "%.2f"},
        {:name => 'Depth', :only => [:variant], :populate => [:line_item]}
      ]
  end

  it "should display the standard edit form" do
    Variant.stub!(:additional_fields).and_return([])
    render '/admin/variants/edit'
        
    response.should have_tag('form[method=?][action=?]', 'post', "") do
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_sku', @variant.sku)
      
      #check that option type and values are displayed (read only)
      with_tag("table") do
        with_tag("td", :text => @option_type.presentation + ":")
        with_tag("td", :text => @option_value.presentation)
      end
      
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_sku', @variant.sku)
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_price', @variant.price)    
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_on_hand', @variant.on_hand)     
    end

  end

  it "should display additional fields when additional_fields is populated" do
    Variant.stub!(:additional_fields).and_return(@additional_fields)
    
    #only stub these two methods because they are the only ones configured
    #to be added to the products edit form
    @variant.stub!(:height).and_return('99')
    @variant.stub!(:width).and_return('6')
    @variant.stub!(:depth).and_return('3')
    
    render '/admin/variants/edit'
    
    response.should have_tag('form[method=?][action=?]', 'post', "") do
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_height', '99.00')
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_width', '6.00')
      
      with_tag("input[type=?][id=?][value=?]", 'text', 'variant_depth', '3')
      
      without_tag("input[type=?][id=?]", 'text', 'product_weight') #ensure that product only width field does not appear
    end
 end

end


