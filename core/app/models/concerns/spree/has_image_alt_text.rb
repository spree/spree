module Spree
  module HasImageAltText
    extend ActiveSupport::Concern

    def image_alt
      return preferred_image_alt if preferred_image_alt.present?
      
      if asset&.filename
        filename = asset.filename.to_s
        filename_without_extension = File.basename(filename, File.extname(filename))
        return filename_without_extension.gsub(/[-_]+/, ' ').strip
      end
      
      I18n.t('spree.image', default: 'Image')
    end
  end
end