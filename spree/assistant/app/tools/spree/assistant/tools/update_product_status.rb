module Spree
  module Assistant
    module Tools
      # Publishes or unpublishes a product.
      #
      # The first mutating tool, and the shape every later one follows: it
      # declares `mutating!` so the turn halts for approval, writes a summary a
      # merchant can judge without reading arguments, and goes through the same
      # workflow the Admin API uses so validations, events and webhooks all fire
      # exactly as they would from the dashboard.
      class UpdateProductStatus < Spree::Assistant::Tool
        STATUSES = %w[active draft archived].freeze

        tool_name 'update_product_status'
        description 'Change whether a product is active, draft or archived. ' \
                    'The merchant must approve this before it happens.'
        permission 'write_products'
        mutating!

        param :id, description: 'Product id or slug', required: true
        param :status, description: "One of: #{STATUSES.join(', ')}", required: true

        def call(id:, status:)
          return { error: "Status must be one of #{STATUSES.join(', ')}" } unless STATUSES.include?(status.to_s)

          product = find_product(id)
          return { error: "No product found for #{id.inspect}" } if product.nil?

          # The permission key got this tool offered; this asks whether the
          # admin may change THIS product. Checked here rather than at proposal
          # time, since approval can come minutes later.
          refusal = unauthorized(:update, product)
          return refusal if refusal

          result = Spree::Products::Update.call(product: product, attributes: { status: status.to_s })

          if result.success?
            { ok: true, id: product.prefixed_id, name: product.name, status: product.reload.status }
          else
            { error: result.error.to_s }
          end
        end

        def summary(arguments)
          product = find_product(arguments[:id])
          label = product&.name || arguments[:id]

          "Set #{label} to #{arguments[:status]}"
        end

        private

        def find_product(id)
          scope = context.accessible(context.store.products, :show)

          scope.find_by_prefix_id(id) || scope.find_by(slug: id)
        rescue ArgumentError, NoMethodError
          scope.find_by(slug: id)
        end
      end
    end
  end
end
