Spree::Order.class_eval do

  def update_line_items(line_item_params)
    return if line_item_params.blank?
    line_item_params.each_value do |attributes|
      if attributes[:id].present?
        self.line_items.find(attributes[:id]).update_attributes!(attributes)
      else
        self.line_items.create!(attributes)
      end
    end
    self.ensure_updated_shipments
  end

end
