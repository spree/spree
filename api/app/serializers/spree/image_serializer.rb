module Spree
  class ImageSerializer < ActiveModel::Serializer
    attributes :id, :position, :attachment_file_name, :attachment_width,
               :attachment_height, :attachment_content_type, :urls,
               :type, :attachment_updated_at, :alt

    def urls
      urls = Spree::Image.attachment_definitions[:attachment][:styles].map do |k,v|
        [k, v]
      end
      urls = Hash[urls]
    end
  end
end
