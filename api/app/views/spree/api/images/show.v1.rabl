object @image
attributes *image_attributes
attributes :viewable_type, :viewable_id
node(:attachment_url) { |i| i.attachment.to_s }
code(:urls) do |v|
  v.attachment.styles.keys.inject({}) { |urls, style| urls[style] = v.attachment.url(style); urls  }
end
