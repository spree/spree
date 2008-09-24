require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')


describe '/product/show' do
  before(:each) do
    @product = mock_model(Product)
    template.stub!(:product_image)
    @product.stub!(:master_price)
    @product.stub!(:name).and_return('Delicious Cows')
    @product.stub!(:has_stock?).and_return(true)
    assigns[:product] = @product
  end

  it "should display the item" do
    render product_path(assigns[:product])
    response.should have_tag('a[href=?]', product_path(@product), /#{@product.name}/)
  end

  describe 'with out-of-stock items' do
    before(:each) do
      @product.stub!(:has_stock?).and_return(false)
    end

    it "should not display if show_zero_stock_products is not set" do
      Spree::Config.stub!(:[]).with(:show_zero_stock_products).and_return(false)
      render '/products/index'
      response.should_not have_tag('a[href=?]', product_path(@product), /#{@product.name}/)
    end

    it "should display if show_zero_stock_products is set" do
      Spree::Config.stub!(:[]).with(:show_zero_stock_products).and_return(true)
      render '/products/index'
      response.should have_tag('a[href=?]', product_path(@product), /#{@product.name}/)
    end

  end
end


