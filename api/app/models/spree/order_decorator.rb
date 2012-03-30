Spree::Order.class_eval do
  def self.build_from_api(user, params)
    order = create
    params[:line_items].each do |variant_id, quantity|
      line_item_params = { :variant_id => variant_id, :quantity => quantity }
      line_item = order.add_variant(Spree::Variant.find(variant_id), quantity)
    end
    order.user = user
    order.email = user.email
    order
  end
end
