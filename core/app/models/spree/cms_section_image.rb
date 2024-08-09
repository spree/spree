module Spree
  class CmsSectionImage < Asset
    IMAGE_COUNT = ['one', 'two', 'three']
    IMAGE_TYPES = ['image/png', 'image/jpg', 'image/jpeg', 'image/gif'].freeze
    IMAGE_SIZE = ['sm', 'md', 'lg', 'xl']

    validates :attachment, attached: true, content_type: IMAGE_TYPES
  end
end
