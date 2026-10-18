module Spree
  module AgentTools
    # Starts a CSV import from a file the merchant provided.
    #
    # Gated on the WRITE scope of what is being imported, computed per call —
    # a customers import needs `write_customers`, a products import
    # `write_products`. A single class-level key could not say that, which is
    # why the resource reached the map read-only; `create_export` answers the
    # same question the same way.
    #
    # Creating the import reads the file's header row and proposes a column
    # mapping. Nothing is written to the catalog until that mapping is
    # confirmed, so this is the safe half of the wizard: the merchant still
    # sees what the columns were taken to mean before any row lands.
    class CreateImport < Spree::AgentTool
      tool_name 'create_import'
      description 'Start a CSV import from a file the merchant provided. Call upload_file ' \
                  'first and pass the file_id it returns. The columns are read and a mapping ' \
                  'proposed; no records change until the mapping is confirmed.'
      # Per-resource, answered in `call` — a class-level key would hide the
      # tool from a caller who may import one kind of record but not another.
      permission nil
      mutating!

      param :resource, description: 'What the file holds: products, customers, purchase_orders',
                       required: true
      param :file_id, description: 'The file_id upload_file returned', required: true

      def call(resource:, file_id:)
        import_class = import_class_for(resource)
        return unknown_resource(resource) if import_class.nil?

        required = "write_#{import_class.required_scope}"
        unless context.holds?(required)
          return { error: "You do not have permission to import #{resource.to_s.tr('_', ' ')}." }
        end

        start(import_class, resource, file_id)
      end

      def summary(arguments)
        "Start a #{arguments[:resource].to_s.tr('_', ' ')} import"
      end

      private

      def start(import_class, resource, file_id)
        owner = importing_user
        return { error: no_user_error } if owner.nil?

        import = import_class.new(store: context.store, user: owner)
        import.attachment = file_id

        refusal = unauthorized(:create, import)
        return refusal if refusal
        return { error: import.errors.full_messages.to_sentence } unless import.save

        mapping = Spree.import_start_mapping_workflow.call(import: import)
        return { error: mapping_failure(mapping, import) } unless mapping.success?

        {
          ok: true,
          id: import.prefixed_id,
          resource: resource.to_s,
          status: import.reload.status,
          # The mapping is the point of this step: the model should read it
          # back and tell the merchant what the columns were taken to mean
          # before anything is written.
          next_step: "Call describe_import_mapping with id #{import.prefixed_id} to see the " \
                     'columns, then confirm it to run the import.',
          dashboard_path: ResourceMap.find('imports')&.dashboard_path_for(import)
        }
      rescue ::CSV::MalformedCSVError, EncodingError => e
        { error: "That file could not be read as CSV: #{e.message}" }
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
        { error: "#{file_id.inspect} is not a file this store uploaded. Call upload_file first." }
      rescue ActiveStorage::FileNotFoundError
        { error: 'That upload did not finish — its bytes are missing. Upload the file again.' }
      end

      def mapping_failure(result, import)
        error = result.error
        message = error.try(:value).is_a?(String) ? error.value : error.to_s

        message.presence || import.processing_errors.presence || 'The file could not be mapped.'
      end

      # An import belongs to a person — it emails them when it finishes and
      # its failed rows are theirs to retry. A grant carries the admin who
      # approved it; a standing key carries whoever minted it, which is the
      # same fallback the Admin API uses.
      def importing_user
        return context.user if context.user.present?

        creator = context.api_key&.created_by
        creator if creator.is_a?(Spree.admin_user_class)
      end

      def no_user_error
        'An import has to belong to a staff member, and this credential names none. ' \
          'Connect an agent through the dashboard, or start the import there.'
      end

      def import_class_for(resource)
        key = resource.to_s.downcase
        Spree::Import.available_types.find { |klass| klass.name.demodulize.underscore == key }
      end

      def unknown_resource(resource)
        {
          error: "Cannot import #{resource.inspect}.",
          available: Spree::Import.available_types.map { |k| k.name.demodulize.underscore }.sort
        }
      end
    end
  end
end
