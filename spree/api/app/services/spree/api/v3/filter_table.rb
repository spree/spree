module Spree
  module Api
    module V3
      # What one model may be filtered and sorted on by one audience, read
      # from the model's Ransack allowlists (see Spree::RansackableAttributes)
      # and its columns. Nothing here declares a filter: the allowlists stay
      # the only source, and this turns them into the published contract that
      # the OpenAPI specs carry and the SDK filter types are generated from.
      #
      #   Spree::Api::V3::FilterTable.for_model(Spree::Order, nil).to_h
      #   # => { 'attributes' => { 'number' => 'text', 'total' => 'decimal', ... },
      #   #      'associations' => { 'line_items' => 'LineItem' },
      #   #      'scopes' => { 'complete' => 'boolean', 'search' => 'text' },
      #   #      'sortable' => ['number', 'total', ...] }
      class FilterTable
        # Associations deeper than this are not part of the contract.
        MAX_DEPTH = 2

        COLUMN_KINDS = {
          string: 'text', text: 'text', citext: 'text', uuid: 'text',
          integer: 'integer', bigint: 'integer',
          decimal: 'decimal', float: 'decimal',
          date: 'date',
          datetime: 'datetime', timestamp: 'datetime', timestamptz: 'datetime',
          boolean: 'boolean'
        }.freeze

        # Raised when an endpoint's table cannot be described — a column of a
        # kind the contract has no predicates for, or two models sharing a name.
        class Error < StandardError; end

        attr_reader :model, :audience

        class << self
          # @param model [Class] an ActiveRecord model
          # @param audience [Symbol, nil] the Ransack auth object: nil for the
          #   back office, `:store` or `:seller`
          # @return [FilterTable]
          def for_model(model, audience)
            cache[[model.name, audience]] ||= new(model, audience)
          end

          # @param controller_class [Class] a Spree::Api::V3::ResourceController
          # @return [Endpoint]
          def for(controller_class)
            Endpoint.new(controller_class)
          end

          # Forgets every computed table, for when the allowlists change at
          # runtime (extensions in `to_prepare`, specs).
          def reset!
            @cache = {}
          end

          # The name a table goes by in the contract: the model's API short
          # name, camelized — `Order`, `LineItem`, `Customer`.
          #
          # @param model [Class]
          # @return [String]
          def name_for(model)
            Spree::Base.polymorphic_api_type(model.name).camelize
          end

          private

          def cache
            @cache ||= {}
          end
        end

        # @param model [Class]
        # @param audience [Symbol, nil]
        def initialize(model, audience)
          @model = model
          @audience = audience
        end

        # @return [String]
        def name
          self.class.name_for(model)
        end

        # @return [Hash{String => String, Hash}] attribute => value kind, or
        #   `{ 'enum' => [values] }` for a status
        def attributes
          @attributes ||= kinds.reject { |_, kind| kind == :unclassified }.compact
        end

        # Declared attributes whose value kind could not be determined; a
        # non-empty list fails the filter table spec.
        #
        # @return [Array<String>]
        def unclassified_attributes
          kinds.select { |_, kind| kind == :unclassified }.keys
        end

        # Renamed columns kept under their old name (`payment_state`, through
        # `alias_attribute`), published until they are removed but left out of
        # the reference. A `ransack_alias` is a deliberate public name and stays.
        #
        # @return [Array<String>]
        def aliased_attributes
          attributes.keys.select { |attribute| model.attribute_aliases.key?(attribute) }
        end

        # @return [Hash{String => FilterTable}]
        def associations
          @associations ||= model.ransackable_associations(audience).sort.each_with_object({}) do |name, tables|
            reflection = model.reflect_on_association(name.to_sym)
            next if reflection.nil? || reflection.polymorphic?

            tables[name.to_s] = self.class.for_model(reflection.klass, audience)
          end
        end

        # @return [Hash{String => String, Array, Hash}] scope => argument type:
        #   one kind, a list of kinds (positional arguments), or
        #   `{ 'list' => kind }` for any number of arguments
        def scopes
          @scopes ||= begin
            declared = (model.respond_to?(:ransackable_scope_types) ? model.ransackable_scope_types : {}).
                       merge(Spree.ransack.custom_scope_types_for(model)).stringify_keys
            model.ransackable_scopes(audience).map(&:to_s).sort.index_with do |scope|
              normalize_scope_type(declared.fetch(scope) { inferred_scope_type(scope) })
            end
          end
        end

        # @return [Array<String>]
        def sortable
          @sortable ||= model.ransortable_attributes(audience).map(&:to_s).select { |attribute| attributes.key?(attribute) }.sort
        end

        # Every table reachable from this one within {MAX_DEPTH} hops,
        # including this one.
        #
        # @return [Hash{String => FilterTable}]
        def reachable(depth = 0, found = {})
          if found.key?(name) && found[name].model != model
            raise Error, "#{found[name].model.name} and #{model.name} are both published as #{name}; give one a distinct api_type"
          end

          found[name] ||= self
          return found if depth >= MAX_DEPTH

          associations.each_value { |table| table.reachable(depth + 1, found) }
          found
        end

        # @return [Hash]
        def to_h
          {
            'attributes' => attributes,
            'associations' => associations.transform_values(&:name),
            'scopes' => scopes
          }
        end

        private

        def kinds
          @kinds ||= model.ransackable_attributes(audience).map(&:to_s).uniq.sort.index_with { |attribute| attribute_kind(attribute) }
        end

        # @return [String, Hash, Symbol, nil] the kind; nil for a default
        #   attribute the model does not have (`position` on a table without
        #   one), `:unclassified` for one the contract cannot describe
        def attribute_kind(attribute)
          aliased = model._ransack_aliases[attribute] || model.attribute_aliases[attribute]
          return attribute_kind(aliased) if aliased
          return ransacker_kind(model._ransackers[attribute]) if model._ransackers.key?(attribute)
          return 'id' if id_attribute?(attribute)
          return 'type' if type_attribute?(attribute)
          return { 'enum' => model.statuses } if attribute == 'status' && model.respond_to?(:statuses)
          return { 'enum' => model.defined_enums[attribute].keys } if model.defined_enums.key?(attribute)
          if (values = inclusion_values(attribute))
            return { 'enum' => values }
          end

          column = model.columns_hash[attribute]
          return COLUMN_KINDS.fetch(column.type, :unclassified) if column
          return 'text' if translated_attribute?(attribute)
          return nil if model.default_ransackable_attributes.include?(attribute)

          :unclassified
        end

        # The fixed list an inclusion validation allows, for a column that
        # holds one of a known set of values (`payment_status`, `kind`).
        def inclusion_values(attribute)
          validator = model.validators_on(attribute.to_sym).find { |candidate| candidate.is_a?(ActiveModel::Validations::InclusionValidator) }
          values = validator&.options&.[](:in)
          values.map(&:to_s).uniq if values.is_a?(Array) && values.all? { |value| value.is_a?(String) || value.is_a?(Symbol) }
        end

        def ransacker_kind(ransacker)
          COLUMN_KINDS.fetch(ransacker.type.to_sym, :unclassified)
        end

        def id_attribute?(attribute)
          attribute == model.primary_key ||
            model.reflect_on_all_associations(:belongs_to).any? { |reflection| reflection.foreign_key.to_s == attribute }
        end

        def type_attribute?(attribute)
          model.respond_to?(:api_type_resolver) && model.api_type_resolver(attribute).present?
        end

        def translated_attribute?(attribute)
          model.respond_to?(:translatable_fields) && model.translatable_fields.map(&:to_s).include?(attribute)
        end

        # What a class method's signature says about its arguments. A `scope`
        # lambda hides its signature behind `(*args, **)`, so an undeclared one
        # is published as taking one text value.
        def inferred_scope_type(scope)
          parameters = model.method(scope).parameters
          return 'text' if parameters.any? { |type, _| type == :keyrest }
          return { 'list' => 'text' } if parameters.any? { |type, _| type == :rest }

          required = parameters.count { |type, _| type == :req }
          case required
          when 0 then 'boolean'
          when 1 then 'text'
          else Array.new(required, 'text')
          end
        end

        def normalize_scope_type(type)
          case type
          when Hash then { 'list' => validate_kind(type.stringify_keys.fetch('list')) }
          when Array then type.map { |kind| validate_kind(kind) }
          else validate_kind(type)
          end
        end

        def validate_kind(kind)
          kind = kind.to_s
          return kind if FilterPredicates::KINDS.include?(kind)

          raise Error, "#{model.name}.ransackable_scope_types names an unknown kind #{kind.inspect}"
        end

        # One list endpoint: the table its model has for the controller's
        # audience, plus what the controller accepts beyond it.
        class Endpoint
          attr_reader :controller_class

          # @param controller_class [Class]
          def initialize(controller_class)
            @controller_class = controller_class
          end

          # @return [Boolean]
          def filterable?
            controller.send(:filterable?)
          end

          # @return [FilterTable]
          def table
            @table ||= FilterTable.for_model(controller.send(:model_class), controller.send(:ransack_auth_object))
          end

          # @return [Array<String>]
          def sortable
            (table.sortable | controller.send(:additional_sort_fields).map(&:to_s)).sort
          end

          # @return [Hash{String => FilterTable}] the tables this endpoint's
          #   filters reach, keyed by name
          def tables
            table.reachable
          end

          # The `x-spree-filters` extension of the endpoint's OpenAPI operation.
          #
          # @return [Hash]
          def to_h
            extension = { 'table' => table.name, 'sortable' => sortable }
            extension['custom_fields'] = true if controller.send(:custom_field_filters?)
            extension
          end

          private

          def controller
            @controller ||= controller_class.new
          end
        end
      end
    end
  end
end
