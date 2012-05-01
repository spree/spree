Spree::ProductsController.class_eval do
  rescue_from CanCan::AccessDenied, :with => :render_404

  private
    def load_product
      @product = Spree::Product.find_by_permalink!(params[:id])
      if !@product.deleted? && (@product.available_on.nil? || @product.available_on.future?)
        # Allow admins to view any yet to be available products
        authorize! :update, Spree::Product, @product
      end
    end
end

