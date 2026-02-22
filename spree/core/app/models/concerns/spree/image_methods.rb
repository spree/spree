module Spree
  module ImageMethods
    extend ActiveSupport::Concern

    def generate_url(size:, gravity: 'centre', quality: 80, background: [0, 0, 0])
      return if size.blank?

      size = size.gsub(/\s+/, '')

      return unless size.match(/(\d+)x(\d+)/)

      width, height = size.split('x').map(&:to_i)
      gravity = translate_gravity_for_mini_magick(gravity)

      # FIXME: bring back support for background color

      cdn_image_url(attachment.variant(resize_and_pad: [width, height, { gravity: gravity }], saver: { quality: quality }))
    end

    def original_url
      cdn_image_url(attachment)
    end

    private

    def translate_gravity_for_mini_magick(gravity)
      variant_processor = Rails.application.config.active_storage.variant_processor

      if gravity.downcase == 'centre' && [:mini_magick, nil].include?(variant_processor)
        'center'
      else
        gravity
      end
    end
  end
end
