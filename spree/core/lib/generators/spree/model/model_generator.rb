require "rails/generators/active_record/model/model_generator"

module Spree
  # spree:model — extend Rails' ActiveRecord model generator with Spree
  # conventions: Spree::Base parent, has_prefix_id, no FK constraints in
  # migrations, null: false on all columns by default, plus opt-in flags
  # for soft-delete (--paranoid) and custom fields (--metafields).
  #
  # spree:api_resource inherits from this — see api_resource_generator.rb.
  class ModelGenerator < ActiveRecord::Generators::ModelGenerator
    def self.source_paths
      # Spree's templates must come FIRST so they override Rails' bundled
      # model.rb.tt and create_table_migration.rb.tt. Thor's template lookup
      # uses first-match across source_paths.
      [File.expand_path('templates', __dir__), *superclass.source_paths]
    end

    class_option :parent,
                 type: :string,
                 default: 'Spree::Base',
                 desc: 'The parent class for the generated model'

    class_option :id_prefix,
                 type: :string,
                 desc: 'Prefix for prefixed IDs (default: snake_cased class name, e.g. brand)'

    class_option :paranoid,
                 type: :boolean,
                 default: false,
                 desc: 'Enable acts_as_paranoid soft-delete (adds deleted_at column + index)'

    class_option :metafields,
                 type: :boolean,
                 default: false,
                 desc: 'Include Spree::Metafields and Spree::Metadata concerns'

    desc 'Creates a new Spree model with prefixed IDs and Spree::Base parent'

    # Override to prevent module file from being created
    def create_module_file
      return
    end

    # Exposed to templates (model.rb.tt, create_table_migration.rb.tt) via
    # the standard generator-method-as-template-helper mechanism.
    no_tasks do
      def id_prefix
        options[:id_prefix] || file_name
      end

      def paranoid?
        options[:paranoid]
      end

      def metafields?
        options[:metafields]
      end

      # Spree models live under app/models/spree/, regardless of whether
      # the user invokes `spree:model Brand` or `spree:model Spree::Brand`.
      # Rails' generator uses `class_path` (the namespace components) to
      # decide where to put the model file; we force `["spree"]`.
      def class_path
        ['spree']
      end

      # Spree tables are prefixed `spree_` (spree_brands, not brands).
      # Rails' `table_name` derives from the class name without namespace
      # prefixing in tables, so we add it explicitly.
      def table_name
        "spree_#{super.delete_prefix('spree_')}"
      end
    end
  end
end
