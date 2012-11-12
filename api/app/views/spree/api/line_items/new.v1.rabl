object false
node(:attributes) { [*line_item_attributes] - [:id] }
node(:required_attributes) { [:variant_id, :quantity] }
