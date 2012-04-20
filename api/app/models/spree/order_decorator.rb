Spree::Order.class_eval do
  def self.build_from_api(user, params)
    order = create
    params[:line_items_attributes].each do |line_item|
      order.add_variant(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
    end

    order.user = user
    order.email = user.email
    order
  end
end
