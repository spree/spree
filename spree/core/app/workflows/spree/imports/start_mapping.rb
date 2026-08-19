module Spree
  module Imports
    # Opens an uploaded file for mapping: reads its headers, creates a mapping
    # row per schema field and guesses which column feeds which.
    #
    # Reading the file is where a malformed CSV shows up, so the caller sees
    # the parse error from here rather than from a later step.
    class StartMapping < Spree::Workflow
      hooks :validate, :after_start_mapping

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_mappings
          step :mark_mapping
          run_hooks :after_start_mapping
        end

        success(import)
      end

      private

      # TODO: seed from the previous import of the same type, so a merchant
      # doesn't map the same columns twice.
      def build_mappings
        import.schema_fields.each do |schema_field|
          mapping = import.mappings.find_or_create_by!(schema_field: schema_field[:name])
          mapping.try_to_auto_assign_file_column(import.csv_headers)
          mapping.save!
        end
      end

      def mark_mapping
        failure(import) unless import.update(status: 'mapping')
      end
    end
  end
end
