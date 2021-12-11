module Spree
  module ImageMethods
    extend ActiveSupport::Concern

    def generate_url(size:, gravity: 'centre', quality: 80, background: [0, 0, 0])
      return if size.blank?

      size = size.gsub(/\s+/, '')

      return unless size.match(/(\d+)x(\d+)/)

      width, height = size.split('x').map(&:to_i)

      # FIXME: bring back support for background color

      polymorphic_path(
        attachment.variant(resize_and_pad: [width, height, { gravity: gravity }], saver: { quality: quality }),
        only_path: true
      )
    end

    def original_url
      polymorphic_path(attachment, only_path: true)
    end
  end
end
