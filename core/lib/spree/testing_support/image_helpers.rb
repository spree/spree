module Spree
  module TestingSupport
    module ImageHelpers
      def create_image(attachable, file)
        image = attachable.images.new
        image.attachment.attach(io: file, filename: File.basename(file))
        image.save!
        file.rewind
        image
      end
    end
  end
end
