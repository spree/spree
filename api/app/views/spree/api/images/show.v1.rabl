object @image
attributes *image_attributes
attributes :viewable_type, :viewable_id
node(:attachment_url) { |i| i.attachment.to_s }
Spree::Image.attachment_definitions[:attachment][:styles].each do |k,v|
  node("#{k}_url") { |i| i.attachment.url(k) }
end
