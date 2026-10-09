module Spree
  module AgentTools
    # Puts a file into the media library, optionally on a product.
    #
    # Creating media needs a file, which an agent had no way to supply until
    # `upload_file` existed — which is why the resource reached the map
    # read-only. The id that tool returns is what this one takes.
    #
    # A row with no owner is a library file: uploaded, not yet placed. Naming
    # a product places it in that product's gallery, which is what a merchant
    # handing over photographs usually means.
    class CreateMedia < Spree::AgentTool
      tool_name 'media_create'
      description 'Add an uploaded file to the media library, or straight onto a product. ' \
                  'Call upload_file first and pass the file_id it returns. Without a product ' \
                  'the file sits in the library for the merchant to place later.'
      permission 'write_media'
      mutating!

      param :file_id, description: 'The file_id upload_file returned', required: true
      param :product_id, description: "A product's prefixed id, to place the file in its gallery"
      param :alt, description: 'Alt text describing the image, for accessibility and SEO'

      def call(file_id:, product_id: nil, alt: nil)
        product = nil
        if product_id.present?
          product = find_product(product_id)
          return { error: "No product found for #{product_id.inspect}." } if product.nil?

          refusal = unauthorized(:update, product)
          return refusal if refusal
        end

        build_and_save(file_id: file_id, product: product, alt: alt)
      end

      def summary(arguments)
        return "Add a file to #{arguments[:product_id]}'s gallery" if arguments[:product_id].present?

        'Add a file to the media library'
      end

      private

      def build_and_save(file_id:, product:, alt:)
        media = Spree::Media.new(store: context.store, alt: alt.presence)
        media.viewable = product if product

        # The signed id is verified by ActiveStorage itself: one that was not
        # issued by this installation does not resolve, so a model cannot
        # invent a reference to someone else's file.
        media.attachment = file_id

        return { error: media.errors.full_messages.to_sentence.presence || 'The file could not be added.' } unless
          media.save

        {
          ok: true,
          id: media.prefixed_id,
          filename: media.attachment.filename.to_s,
          media_type: media.media_type,
          product_id: product&.prefixed_id,
          # The media library has no page of its own in the map, so the link
          # that helps is the product's — where the merchant will look at it.
          dashboard_path: product && ResourceMap.find('products')&.dashboard_path_for(product)
        }.compact
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
        { error: "#{file_id.inspect} is not a file this store uploaded. Call upload_file first." }
      rescue ActiveStorage::FileNotFoundError
        { error: 'That upload did not finish — its bytes are missing. Upload the file again.' }
      end

      def find_product(id)
        context.accessible(Spree::Product.for_store(context.store), :update).find_by_prefix_id(id)
      rescue StandardError
        nil
      end
    end
  end
end
