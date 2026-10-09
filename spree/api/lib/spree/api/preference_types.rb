require 'spree/api/preference_families'

module Spree
  module Api
    # Renders each configurable family's preference schemas
    # ({Spree::Api::PreferenceFamilies}) into the TypeScript types the Admin
    # and Seller SDKs export: one interface per subtype Spree ships, a map from
    # `type` to it, and the family's resource with `preferences` typed by its
    # `type`.
    #
    # The map is an interface, so an extension types its own subtypes by
    # declaration merging. A union with a catch-all member for unknown types
    # would stop TypeScript from narrowing on `type` at all.
    #
    # Run by `rake typelizer:generate`; `preference_types_spec.rb` fails when
    # the committed files no longer match the declarations.
    class PreferenceTypes
      HEADER = "// This file is auto-generated from Spree's preference declarations by `rake typelizer:generate`. Do not edit directly.\n".freeze

      FILES = {
        'packages/admin-sdk/src/types/preferences.ts' => PreferenceFamilies::REGISTRIES.keys,
        'packages/seller-sdk/src/types/preferences.ts' => PreferenceFamilies::SELLER
      }.freeze

      # Families serialized as rows of their own; calculators are nested in
      # their owner and get only the map.
      RESOURCES = (PreferenceFamilies::REGISTRIES.keys - %w[DeliveryCalculator PromotionCalculator]).freeze

      # @return [Hash{String => String}] file contents keyed by path under the monorepo root
      def render
        FILES.transform_values { |families| source(PreferenceFamilies.schemas(families)) }
      end

      # @param root [Pathname] the monorepo root
      # @return [void]
      def write!(root)
        render.each { |path, content| File.write(root.join(path), content) }
      end

      private

      NARROWED = <<~TS.freeze
        /** `Resource` with its `preferences` typed by its `type`, one member per entry of `Map`. */
        type Narrowed<Resource, Map> = {
          [Type in keyof Map]: Omit<Resource, 'type' | 'preferences'> & {
            type: Type
            preferences: Map[Type]
          }
        }[keyof Map]
      TS

      def source(families)
        resources = families.keys & RESOURCES
        imports = resources.map { |family| "import type #{family} from './generated/#{family}'\n" }.join
        parts = families.flat_map { |family, members| family_parts(family, members, resources.include?(family)) }
        parts.unshift(NARROWED) if resources.any?
        parts.unshift(imports) if imports.present?

        HEADER + parts.join("\n")
      end

      def family_parts(family, members, resource)
        label = family.titleize.downcase
        parts = members.map do |type, schema|
          name = PreferenceFamilies.member_name(family, type)
          # Deprecated settings are still accepted on write but never read back.
          properties = schema['properties'].reject { |_key, property| property['deprecated'] }
          next "/** Settings of the `#{type}` #{label}: none. */\nexport type #{name} = Record<string, never>\n" if properties.empty?

          fields = properties.map { |key, property| "#{field_comment(property)}  #{key}: #{ts_type(property)}\n" }.join
          "/** Settings of the `#{type}` #{label}. */\nexport interface #{name} {\n#{fields}}\n"
        end

        map = "#{family}PreferencesMap"
        entries = members.keys.map { |type| "  #{type}: #{PreferenceFamilies.member_name(family, type)}\n" }.join
        ignore = members.empty? ? "// biome-ignore lint/suspicious/noEmptyInterface: extensions add their types by declaration merging\n" : ''
        parts << "/**\n * The settings of each #{label} type Spree ships, by `type`. An interface,\n" \
                 " * so an extension types its own by declaration merging.\n */\n" \
                 "#{ignore}export interface #{map} {#{"\n#{entries}" if entries.present?}}\n"
        parts << "/** #{label.match?(/\A[aeiou]/) ? 'An' : 'A'} #{label} whose `preferences` are typed by its `type`. */\nexport type Typed#{family} = Narrowed<#{family}, #{map}>\n" if resource
        parts
      end

      def field_comment(property)
        note = if property['x-spree-secret'] then 'Masked when read (`••••1234`); send it back unchanged to keep it, `null` to clear it.'
               elsif property.dig('items', 'x-spree-prefix') then "Prefixed `#{property.dig('items', 'x-spree-prefix')}_` ids."
               elsif property['format'] == 'money' then 'An amount, as an exact decimal string.'
               elsif property['format'] then "Format: `#{property['format']}`."
               end
        note ? "  /** #{note} */\n" : ''
      end

      def ts_type(schema)
        types = Array(schema['type'])
        base = base_type(schema, (types - ['null']).first)
        types.include?('null') ? "#{base} | null" : base
      end

      def base_type(schema, type)
        return schema['enum'].compact.map { |value| value.is_a?(String) ? "'#{value}'" : value.to_s }.join(' | ') if schema['enum']

        case type
        when 'string' then 'string'
        when 'integer', 'number' then 'number'
        when 'boolean' then 'boolean'
        when 'array' then schema['items'] ? "Array<#{ts_type(schema['items'])}>" : 'Array<unknown>'
        when 'object'
          if schema['properties']
            "{ #{schema['properties'].map { |key, property| "#{key}: #{ts_type(property)}" }.join('; ')} }"
          elsif schema['additionalProperties'].is_a?(Hash)
            "Record<string, #{ts_type(schema['additionalProperties'])}>"
          else
            'Record<string, unknown>'
          end
        else 'unknown'
        end
      end
    end
  end
end
