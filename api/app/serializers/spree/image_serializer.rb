module Spree
  class ImageSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.image_attributes
    attributes  :id, :position, :attachment_file_name, :attachment_width,
                :attachment_height, :attachment_content_type, :urls,
                :type, :attachment_updated_at, :alt, :mini_url, :small_url,
                :product_url, :large_url

    def mini_url
      object.attachment(:mini)
    end

    def small_url
      object.attachment(:small)
    end

    def product_url
      object.attachment(:product)
    end

    def large_url
      object.attachment(:large)
    end

    def urls
      urls = Spree::Image.attachment_definitions[:attachment][:styles].map do |k,v|
        [k, v]
      end
      urls = Hash[urls]
    end
  end
end
