require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe '/products/index' do
  before(:each) do
    @product = mock_model(Product)
    template.stub!(:small_image)
    template.stub!(:breadcrumbs).and_return("")
    @product.stub!(:master_price)
    @product.stub!(:name).and_return('Delicious Cows')
    @product.stub!(:has_stock?).and_return(true)
    assigns[:products] = [@product]

    # TODO: put these pagination stubs into a helper?
    assigns[:products].stub!(:page_count).and_return(1)
    assigns[:products].stub!(:first_page).and_return(true)
    assigns[:products].stub!(:previous_page?).and_return(false)
    assigns[:products].stub!(:next_page?).and_return(false)
    template.stub!(:windowed_pagination_links).and_return(false)
    template.stub_render(:partial => 'shared/taxonomies')
  end

  it "should display items in stock" do
    render '/products/index'
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

