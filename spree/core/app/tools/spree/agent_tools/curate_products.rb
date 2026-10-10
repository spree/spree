module Spree
  module AgentTools
    # Puts products into a category, collection, catalog or price list, and
    # takes them out again — through the Admin API's own nested products
    # endpoint, which every curating parent exposes the same way.
    #
    # Merchandising is largely membership, so this is the write a merchant
    # asks for most. One tool over every parent, because the endpoint is
    # uniform and the registry derives which parents have it.
    class CurateProducts < Spree::AgentTool
      tool_name 'curate_products'
      description 'Add products to a category, collection, catalog or price list, or remove ' \
                  'them. Find the parent and the products with search_resources first and pass ' \
                  'their ids. The result says how many memberships actually changed.'
      # Gated per parent in `call`: curating a category needs
      # write_categories and a price list write_products.
      permission nil
      mutating!

      param :target, description: 'What to curate: category, collection, catalog or price_list',
                     required: true
      param :id, description: "The parent's prefixed id, as it appears in search results",
                 required: true
      param :products, type: :array, items: :string,
                       description: 'Prefixed ids of the products to add or remove', required: true
      param :operation, description: '"add" (the default) or "remove"'

      # Offered only to a caller who can curate at least one parent.
      def permitted?
        MembershipMap.all.any? { |entry| context.holds?(entry.permission) }
      end

      def call(target:, id:, products:, operation: nil)
        entry = MembershipMap.find(target)
        return unknown_target(target) if entry.nil?
        return { error: "#{entry.target} cannot be curated." } if entry.api_path.blank?

        ids = Array(products).map(&:to_s).reject(&:blank?)
        return { error: 'Give at least one product.' } if ids.empty?

        removing = operation.to_s.casecmp('remove').zero?
        response = dispatch.call(
          method: removing ? :delete : :post,
          path: entry.api_path.sub(/:\w+_id/, id.to_s),
          body: { product_ids: ids }
        )
        return { error: response.error_message } unless response.success?

        result(entry, id, response.body, removing)
      end

      def summary(arguments)
        count = Array(arguments[:products]).size
        noun = 'product'.pluralize(count)
        parent = arguments[:target].to_s.tr('_', ' ')

        if arguments[:operation].to_s.casecmp('remove').zero?
          "Remove #{count} #{noun} from #{parent} #{arguments[:id]}"
        else
          "Add #{count} #{noun} to #{parent} #{arguments[:id]}"
        end
      end

      private

      def dispatch
        @dispatch ||= ApiDispatch.new(context)
      end

      # The endpoint counts what actually changed — an id already a member
      # changes nothing, and one naming no product in this store is ignored.
      def result(entry, id, body, removing)
        counted = body.is_a?(Hash) ? body : {}

        {
          ok: true,
          target: entry.target,
          id: id,
          removing ? :removed : :added => counted['removed_count'] || counted['added_count'] || 0
        }
      end

      def unknown_target(target)
        allowed = MembershipMap.all.select { |entry| context.holds?(entry.permission) }.map(&:target).sort

        { error: "Cannot curate #{target.inspect}.", available_targets: allowed }
      end
    end
  end
end
