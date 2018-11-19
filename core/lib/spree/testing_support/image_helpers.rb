module Spree
  module TestingSupport
    module ImageHelpers
      def create_image(attachable, file)
        # user paperclip to attach an image
        if Rails.application.config.use_paperclip
          attachable.images.create!(attachment: file)
        # use ActiveStorage (default)
        else
          image = attachable.images.new
          image.attachment.attach(io: file, filename: File.basename(file))
          image.save!
          file.rewind
          image
        end
      end
    end
  end
end
