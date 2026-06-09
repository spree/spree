require "rails/generators/active_record/model/model_generator"

module Spree
  class ModelGenerator < ActiveRecord::Generators::ModelGenerator
    def self.source_paths
      [File.expand_path('templates', __dir__), *superclass.source_paths]
    end

    class_option :parent,
                 type: :string,
                 default: 'Spree.base_class',
                 desc: 'The parent class expression for the generated model'

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

    desc 'Creates a new Spree model with prefixed IDs and Spree.base_class parent'

    def create_module_file
      return
    end

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

      def class_path
        ['spree']
      end

      def table_name
        "spree_#{super.delete_prefix('spree_')}"
      end

      # Resolution: explicit class hint in attribute spec → Spree.user_class
      # for user-named columns → Spree.admin_user_class for admin-user-named
      # columns → Spree::<CamelCasedName> default. The Rails attribute parser
      # splits on `:` so explicit hints can only be unqualified names; users
      # needing a namespace edit the generated belongs_to.
      def belongs_to_class_name_expr(attribute)
        explicit = attribute.attr_options.keys.find { |k| k.to_s.match?(/\A(::)?[A-Z]/) }
        return "'#{explicit}'" if explicit

        case attribute.name
        when 'user', 'user_id'
          '"::#{Spree.user_class}"'
        when 'admin_user', 'admin_user_id', 'created_by', 'created_by_id',
             'approver', 'approver_id', 'canceler', 'canceler_id'
          '"::#{Spree.admin_user_class}"'
        else
          "'Spree::#{attribute.name.camelize}'"
        end
      end

      def column_default_for(attribute)
        return nil unless attribute.attr_options.key?(:default)

        value = attribute.attr_options[:default]
        case value
        when true, false, nil then value.inspect
        when Numeric then value.to_s
        else value.to_s.inspect
        end
      end
    end
  end
end
