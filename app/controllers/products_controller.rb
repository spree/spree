class ProductsController < Admin::BaseController
  layout 'application'
  
  resource_controller
  actions :show, :index

  index do
    before do
      @product_cols = 3
    end
  end

  def change_image
    @product = Product.available.find_by_param(params[:id])
    img = Image.find(params[:image_id])
    render :partial => 'image', :locals => {:image => img}
  end

  private

    def collection
      @collection ||= Product.available.find(:all, :page => {:start => 1, :size => 10, :current => params[:page]}, :include => :images)
    end
end
