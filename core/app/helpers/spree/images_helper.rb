module Spree
  module ImagesHelper
    # convert images to webp with some sane optimization defaults
    def spree_image_variant_options(options = {})
      {
        saver: {
          strip: true,
          quality: 75,
          lossless: false,
          alpha_q: 85,
          reduction_effort: 6,
          smart_subsample: true
        },
        format: :webp
      }.merge(options)
    end
  end
end
