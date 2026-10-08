module Spree
  module AgentTools
    # Puts products into a category, collection, catalog or price list, and
    # takes them out again.
    #
    # Merchandising is largely membership — what sits in which category, what
    # a wholesale catalog carries, what a price list prices — so this is one
    # of the writes a merchant asks for most. One tool over every curating
    # parent, derived from the membership map, because the Admin API gives
    # them all one nested surface and a parent that adopts it later should
    # need no new tool.
    class CurateProducts < Spree::AgentTool
      tool_name 'curate_products'
      description 'Add products to a category, collection, catalog or price list, or remove ' \
                  'them. Find the parent and the products with search_resources first and pass ' \
                  'their ids. Ids naming nothing in this store are ignored, and the result ' \
                  'says how many memberships actually changed.'
      # Gated per parent in `call`: curating a category needs
      # write_categories and a price list write_products, so a class-level
      # key would hide the tool from a caller holding one but not the other.
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
      #
      # The class declares no permission, because each parent carries its own
      # — but without this a read-only grant was shown a write it could never
      # use, which is exactly the "a tool you cannot see is one this store has
      # not granted" promise the server makes in its instructions.
      def permitted?
        MembershipMap.all.any? { |entry| context.holds?(entry.permission) }
      end

      def call(target:, id:, products:, operation: nil)
        entry = MembershipMap.find(target)
        return unknown_target(target) if entry.nil?
        return forbidden(entry) unless context.holds?(entry.permission)

        parent = find_parent(entry, id)
        return missing_parent(entry, id) if parent.nil?

        # The scope check answers tenancy; this answers which records within
        # it — a role that may edit only its own categories cannot curate
        # another's, the same two steps the controller takes.
        refusal = unauthorized(:update, parent)
        return refusal if refusal

        records = find_products(products)
        return no_products if records.empty?

        removing?(operation) ? remove(entry, parent, records) : add(entry, parent, records)
      end

      def summary(arguments)
        count = Array(arguments[:products]).size
        noun = 'product'.pluralize(count)
        parent = arguments[:target].to_s.tr('_', ' ')

        if removing?(arguments[:operation])
          "Remove #{count} #{noun} from #{parent} #{arguments[:id]}"
        else
          "Add #{count} #{noun} to #{parent} #{arguments[:id]}"
        end
      end

      private

      def removing?(operation)
        operation.to_s.casecmp('remove').zero?
      end

      # Counted by re-reading membership rather than by trusting the input: a
      # product already a member changes nothing, and the merchant is told
      # what actually happened rather than what was asked for.
      def add(entry, parent, records)
        before = member_ids(parent, records)
        entry.add(parent, records.reject { |record| before.include?(record.id) })
        gained = member_ids(parent, records) - before

        { ok: true, target: entry.target, id: parent.prefixed_id,
          added: gained.size, already_present: before.size }
      end

      def remove(entry, parent, records)
        before = member_ids(parent, records)
        entry.remove(parent, records.select { |record| before.include?(record.id) })
        lost = before - member_ids(parent, records)

        { ok: true, target: entry.target, id: parent.prefixed_id,
          removed: lost.size, not_a_member: records.size - before.size }
      end

      def member_ids(parent, records)
        parent.products.where(id: records.map(&:id)).reorder(nil).distinct.pluck(:id).to_set
      end

      def find_parent(entry, id)
        context.accessible(entry.model_class.for_store(context.store), :update).find_by_prefix_id(id)
      end

      # An id naming nothing is dropped rather than refused, which is what the
      # Admin API's own bulk writes do — the counts are what tell the merchant
      # which ones landed.
      def find_products(ids)
        decoded = Array(ids).filter_map do |id|
          Spree::Product.decode_prefixed_id(id) if Spree::PrefixedId.prefixed_id?(id.to_s)
        end
        return [] if decoded.empty?

        context.accessible(Spree::Product.for_store(context.store), :update).where(id: decoded).to_a
      end

      # Only the parents this caller can actually curate, so a model
      # correcting itself does not pick one it will then be refused.
      def unknown_target(target)
        allowed = MembershipMap.all.select { |entry| context.holds?(entry.permission) }.map(&:target).sort

        { error: "Cannot curate #{target.inspect}.", available_targets: allowed }
      end

      def forbidden(entry)
        { error: "You do not have permission to change which products a #{label(entry)} holds." }
      end

      def missing_parent(entry, id)
        { error: "No #{label(entry)} found for #{id.inspect}." }
      end

      def no_products
        { error: 'None of those ids name a product in this store.' }
      end

      def label(entry)
        entry.target.tr('_', ' ')
      end
    end
  end
end
