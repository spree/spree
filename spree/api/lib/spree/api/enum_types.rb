module Spree
  module Api
    # Renders every open value list the serializers name (`enum_type_name:`,
    # see {Typelizer::OpenEnums}) into `@spree/core`, once, as both the
    # built-in values and the type. Each SDK's `Enums.ts` re-exports the type
    # from there instead of carrying its own copy, and the dashboards read the
    # values instead of repeating them by hand.
    #
    # Run by `rake typelizer:generate`; `enum_types_spec.rb` fails when the
    # committed file no longer matches the serializers.
    class EnumTypes
      class ConflictError < StandardError; end

      HEADER = "// This file is auto-generated from the API serializers by `rake typelizer:generate`. Do not edit directly.\n".freeze
      PATH = 'packages/core/src/enums.generated.ts'.freeze
      LINE_WIDTH = 100

      # @param properties [Array<Typelizer::Property>] every named enum property, across all serializers
      def initialize(properties = self.class.serializer_properties)
        @properties = properties
      end

      # @return [Array<Typelizer::Property>] the named enum properties of every serializer each Typelizer writer emits
      def self.serializer_properties
        Typelizer.configuration.writers.keys
                 .flat_map { |writer_name| Typelizer.interfaces(writer_name: writer_name) }
                 .flat_map(&:enum_types)
      end

      # @return [Hash{String => Array<String>}] built-in values keyed by type name
      # @raise [ConflictError] when two serializers give one type name different values
      def lists
        @lists ||= @properties
                   .select(&:enum_type_name)
                   .reject { |property| Typelizer::OpenEnums::CLOSED_TYPE_NAMES.include?(property.enum_type_name) }
                   .group_by(&:enum_type_name)
                   .sort
                   .to_h { |name, properties| [name, values_of(name, properties)] }
      end

      # @return [String] the file's contents
      def render
        HEADER + lists.map { |name, values| definition(name, values) }.join
      end

      # @param root [Pathname] the monorepo root
      # @return [void]
      def write!(root)
        File.write(root.join(PATH), render)
      end

      # @param name [String] a type name, e.g. `ProductStatus`
      # @return [String] the constant holding its values, e.g. `PRODUCT_STATUSES`
      def self.constant_name(name)
        name.underscore.pluralize.upcase
      end

      private

      def values_of(name, properties)
        variants = properties.map { |property| property.enum.map(&:to_s) }.uniq
        return variants.first if variants.one?

        raise ConflictError, "#{name} is declared with different values: " \
                             "#{variants.map { |values| values.join(', ') }.join(' / ')}. " \
                             'Give every serializer the same list, or give the lists different names.'
      end

      def definition(name, values)
        constant = self.class.constant_name(name)
        quoted = values.map { |value| "'#{value}'" }
        line = "export const #{constant} = [#{quoted.join(', ')}] as const"
        line = "export const #{constant} = [\n#{quoted.map { |value| "  #{value},\n" }.join}] as const" if line.length > LINE_WIDTH
        type = "export type #{name} = (typeof #{constant})[number] | (string & {})"
        type = "export type #{name} =\n  | (typeof #{constant})[number]\n  | (string & {})" if type.length > LINE_WIDTH

        "\n/** The built-in values of `#{name}`. Extensions may add more. */\n#{line}\n#{type}\n"
      end
    end
  end
end
