module Spree
  module HasImageAltText
    extend ActiveSupport::Concern

    included do
      # Define the image_alt method when the concern is included
      define_method :image_alt do
        return preferred_image_alt if preferred_image_alt.present?
        
        if asset&.filename
          filename = asset.filename.to_s
          filename_without_extension = File.basename(filename, File.extname(filename))
          return filename_without_extension.tr('-_', ' ')
        end
        
        "Image"
      end
    end
  end
end