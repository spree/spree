module Spree
  module AgentTools
    # Exports records to a CSV the merchant can download.
    #
    # Mutating not because it changes the store — it does not — but because
    # it produces a file of store data and emails a link to it. That leaves
    # the building, so a merchant decides, not the model.
    class CreateExport < Spree::AgentTool
      tool_name 'create_export'
      description 'Export records to a CSV file. Say which kind of records and, ' \
                  'optionally, the same filters search_resources accepts. The merchant ' \
                  'approves before the file is generated.'
      # Exports are gated on the READ scope of what is being exported — the
      # Admin API treats an export as a read, because that is what it is.
      # Checked per resource in `call`, since exporting orders and exporting
      # products are different permissions.
      permission 'read_products'
      mutating!

      param :resource, description: 'What to export: products, orders, customers, gift_cards',
                       required: true
      param :filters, type: :object,
                      description: 'Optional Ransack filters, e.g. {"status_eq": "active"}'

      def call(resource:, filters: nil)
        export_class = export_class_for(resource)
        return unknown_resource(resource) if export_class.nil?

        required = "read_#{export_class.required_scope}"
        unless context.permitted?(required)
          return { error: "You do not have permission to export #{resource.to_s.tr('_', ' ')}." }
        end

        export = export_class.new(
          store: context.store,
          # The export builds its own ability from this user, so the file
          # contains exactly the records that admin could see — record-level
          # rules included.
          user: context.user,
          format: 'csv',
          search_params: filters.presence
        )

        refusal = unauthorized(:create, export)
        return refusal if refusal

        # Saving publishes `export.created`, which is what actually enqueues
        # generation. (`generate_async` hands a raw id to a job that expects a
        # prefixed one — the subscriber is the working path.)
        return { error: export.errors.full_messages.to_sentence } unless export.save

        {
          ok: true,
          id: export.prefixed_id,
          resource: resource.to_s,
          message: 'The export is being prepared; it will appear under Settings → Exports.'
        }
      end

      def summary(arguments)
        label = arguments[:resource].to_s.tr('_', ' ')
        return "Export all #{label}" if arguments[:filters].blank?

        filters = arguments[:filters].keys.map { |key| key.to_s.tr('_', ' ') }.join(', ')
        "Export #{label} filtered by #{filters}"
      end

      private

      # Only the export kinds Spree actually ships, resolved by name rather
      # than constantized from model input.
      def export_class_for(resource)
        key = resource.to_s.downcase
        Spree::Export.descendants.find do |klass|
          klass.name.demodulize.underscore == key
        end
      end

      def unknown_resource(resource)
        {
          error: "Cannot export #{resource.inspect}",
          available: Spree::Export.descendants.map { |k| k.name.demodulize.underscore }.sort
        }
      end
    end
  end
end
