Spree::Order.class_eval do
  def self.build_from_api(user, params)
    order = create
    params[:line_items_attributes] ||= []
    unless params[:line_items_attributes].empty?
      params[:line_items_attributes].each_key do |k|
        order.add_variant(Spree::Variant.find(params[:line_items_attributes][k][:variant_id]), params[:line_items_attributes][k][:quantity])
      end
    end

    order.user = user
    order.email = user.email
    order
  end
end
