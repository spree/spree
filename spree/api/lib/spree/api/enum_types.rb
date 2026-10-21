module Spree
  module Api
    # Renders every value list the serializers name (`enum_type_name:`, see
    # {Typelizer::OpenEnums}) into `@spree/core`, once, as both the values and
    # the type — open unless the name is one of `CLOSED_LIST_NAMES`. Each SDK's `Enums.ts` re-exports the type
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

      # Walks every property rather than Typelizer's own `enum_types`, which
      # keeps one property per name within a serializer and so would hide two
      # attributes of one serializer that disagree.
      #
      # @return [Array<Typelizer::Property>] the named enum properties of every serializer each Typelizer writer emits
      def self.serializer_properties
        Typelizer.configuration.writers.keys
                 .flat_map { |writer_name| Typelizer.interfaces(writer_name: writer_name) }
                 .flat_map { |interface| named_properties(interface.properties + interface.trait_interfaces.flat_map(&:properties)) }
      end

      # @param properties [Array<Typelizer::Property>]
      # @return [Array<Typelizer::Property>] those carrying a named list, nested and inline ones included
      def self.named_properties(properties)
        properties.flat_map do |property|
          nested = property.nested_properties.to_a
          nested += property.type.properties if property.type.is_a?(Typelizer::Interface) && property.type.inline?

          [property, *named_properties(nested)]
        end.select { |property| property.enum && property.enum_type_name }
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

      # @return [Array<String>] closed list names no serializer declares any more
      def stale_closed_names
        Typelizer::OpenEnums::CLOSED_LIST_NAMES - lists.keys
      end

      # @return [String] the file's contents
      def render
        HEADER + lists.map { |name, values| definition(name, values) }.join + built_in_status
      end

      # @param root [Pathname] the monorepo root
      # @return [void]
      # @raise [ConflictError] when `CLOSED_LIST_NAMES` names a list no serializer declares
      def write!(root)
        raise ConflictError, "No serializer names #{stale_closed_names.join(', ')}; remove it from CLOSED_LIST_NAMES." if stale_closed_names.any?

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

      # Every built-in value of every status list, so a surface that styles
      # statuses can be checked for one the server added.
      def built_in_status
        members = lists.keys.grep(/Status\z/).map { |name| "  | (typeof #{self.class.constant_name(name)})[number]\n" }
        return '' if members.empty?

        "\n/** Every built-in value of every status list above. */\nexport type BuiltInStatus =\n#{members.join}"
      end

      def definition(name, values)
        constant = self.class.constant_name(name)
        quoted = values.map { |value| "'#{value}'" }
        line = "export const #{constant} = [#{quoted.join(', ')}] as const"
        line = "export const #{constant} = [\n#{quoted.map { |value| "  #{value},\n" }.join}] as const" if line.length > LINE_WIDTH

        if Typelizer::OpenEnums.closed?(name)
          "\n/** Every value of `#{name}`. */\n#{line}\nexport type #{name} = (typeof #{constant})[number]\n"
        else
          type = "export type #{name} = (typeof #{constant})[number] | (string & {})"
          type = "export type #{name} =\n  | (typeof #{constant})[number]\n  | (string & {})" if type.length > LINE_WIDTH

          "\n/** The built-in values of `#{name}`. Extensions may add more. */\n#{line}\n#{type}\n"
        end
      end
    end
  end
end
