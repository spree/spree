LineItem.class_eval do
  def description
    d = variant.product.name.clone
    d << " (#{variant.options_text})" unless variant.option_values.empty?
    d
  end
end