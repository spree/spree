Spree::Order.class_eval do
  def self.build_from_api(user, params)
    order = create
    params[:line_items_attributes] ||= []
    unless params[:line_items_attributes].empty?
      params[:line_items_attributes].each_key do |k|
        line_item = params[:line_items_attributes][k]
        order.contents.add(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
      end
    end

    order
  end

  def update_line_items(line_item_params)
    line_item_params.each do |line_item|
      self.contents.add(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
    end
  end
end
