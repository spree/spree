module Spree
  module Api
    module V2
      module StoreMediaSerializerImagesConcern
        extend ActiveSupport::Concern

        included do
          def self.store_image_url_for(store, attribute_name)
            attachment = store.send(attribute_name)
            return unless attachment.attached?

            url_helpers.cdn_image_url(attachment)
          end

          attribute :logo do |store|
            store_image_url_for store, :logo
          end

          attribute :mailer_logo do |store|
            store_image_url_for store, :mailer_logo
          end

          attribute :favicon_path do |store|
            store_image_url_for store, :favicon_image
          end
        end
      end
    end
  end
end
