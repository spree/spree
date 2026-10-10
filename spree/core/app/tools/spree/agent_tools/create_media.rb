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
        # Placement is the path: nested under a product puts the file in that
        # product's gallery, the flat one leaves it in the library. The
        # endpoint resolves the parent, checks it and verifies the signed id,
        # so there is nothing to look up here first.
        path = if product_id.present?
                 "/api/v3/admin/products/#{product_id}/media"
               else
                 '/api/v3/admin/media'
               end

        response = ApiDispatch.new(context).call(
          method: :post, path: path, body: { signed_id: file_id, alt: alt.presence }.compact
        )
        unless response.success?
          # The endpoint speaks about signed references in general, since many
          # of its parameters are one. Here it is always a file, so the
          # refusal names the tool that produces a valid id.
          message = response.error_message
          if response.status == 422 && message.to_s.match?(/signed reference/i)
            message = "#{file_id.inspect} is not a file this store uploaded, or it has expired. " \
                      'Call upload_file first and pass the file_id it returns.'
          end

          return { error: message }
        end

        media = response.data.to_h

        {
          ok: true,
          id: media['id'],
          filename: media['filename'],
          media_type: media['media_type'],
          product_id: product_id.presence,
          # The media library has no page of its own in the map, so the link
          # that helps is the product's — where the merchant will look at it.
          dashboard_path: product_id.presence && dashboard_path_for(product_id)
        }.compact
      end

      def summary(arguments)
        return "Add a file to #{arguments[:product_id]}'s gallery" if arguments[:product_id].present?

        'Add a file to the media library'
      end

      private

      def dashboard_path_for(product_id)
        path = ResourceMap.find('products')&.dashboard_path
        return if path.blank?

        format(path, id: product_id)
      end
    end
  end
end
