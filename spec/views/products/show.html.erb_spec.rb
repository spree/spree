require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')


describe '/product/show' do
  before(:each) do
    template.stub!(:product_image)
    @product = Product.new(:name => 'Delicious Cows', :permalink => 'delicious-cows',
                           :description => 'Cows are delicious!', :master_price => 45.00,
                           :variants => [Variant.new]
    )
    @product.stub!(:images).and_return(mock(Image, :size => 1))
    assigns[:product] = @product
  end

  it "should display the item" do
    render '/products/show'
    response.should have_tag('td[class=?]', 'product-name', /#{@product.name}/)
  end

  describe 'with out-of-stock items' do
    before(:each) do
      @product.stub!(:has_stock?).and_return(false)
    end

    it "should not display product if allow_backorders is not set" do
      Spree::Config.stub!(:[]).with(:allow_backorders).and_return(false)
      render '/products/show'
      response.should have_tag('strong', /Out of Stock/)
      response.should_not have_tag('input[type=?]', 'submit')
    end

    it "should display product if allow_backorders is set" do
      Spree::Config.stub!(:[]).with(:allow_backorders).and_return(true)
      render '/products/show'
      response.should_not have_tag('strong', /Out of Stock/)
      response.should have_tag('input[type=?]', 'submit')
    end
  end

  # NOTE: the behavior of variants is largely described thru the variant_options
  #       helper method in app/helpers/spree/base_helpers.rb.  For that reason,
  #       the variant testing lives there

end


