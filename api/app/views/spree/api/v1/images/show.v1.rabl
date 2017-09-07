object @image
attributes *image_attributes
attributes :viewable_type, :viewable_id
Spree::Image.attachment_definitions[:attachment][:styles].each do |k, _v|
  node("#{k}_url") { |i| i.attachment.url(k) }
end
