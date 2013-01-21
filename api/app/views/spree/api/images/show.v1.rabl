object @image
attributes *image_attributes
attributes :viewable_type, :viewable_id
node(:attachment_url) { |i| i.attachment.to_s }
