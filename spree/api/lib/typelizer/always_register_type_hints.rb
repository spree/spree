module Typelizer
  module DSL
    # Spree generates OpenAPI schemas on demand and keeps Typelizer disabled at boot
    # (so types are not regenerated on every code reload). Upstream `typelize` only
    # records its type hints when Typelizer is enabled at the moment the serializer
    # class body runs — see `assign_type_information`'s `return unless Typelizer.enabled?`.
    # A serializer autoloaded while disabled (e.g. by an earlier spec) therefore loses
    # its hints, and schema generation later falls back to `object` for those attributes
    # (notably the `id`/`created_at`/`updated_at` declared on the shared BaseSerializer).
    #
    # Record the metadata unconditionally — it is harmless to store and is required for
    # on-demand schema generation. Boot-time file generation stays gated by `enabled?`.
    module AlwaysRegisterTypeHints
      def assign_type_information(attribute_name, attributes)
        attributes.each do |name, attrs|
          next unless name

          store_type(attribute_name, name, TypeParser.parse_declaration(attrs))
        end
      end
    end

    ClassMethods.prepend(AlwaysRegisterTypeHints)
  end
end
