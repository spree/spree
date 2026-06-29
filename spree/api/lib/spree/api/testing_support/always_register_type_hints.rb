module Spree
  module Api
    module TestingSupport
      # Typelizer only records its `typelize` hints when enabled at the moment the
      # serializer class body runs (see `assign_type_information`'s `return unless
      # Typelizer.enabled?`). Spree keeps Typelizer disabled at boot and only enables it
      # while generating OpenAPI schemas on demand (see SchemaHelper#with_typelizer_enabled).
      # A serializer autoloaded by an earlier spec while disabled would otherwise lose its
      # hints, and Rswag schema validation would see `object` for the `id`/`created_at`/
      # `updated_at` declared on the shared BaseSerializer.
      #
      # Record the metadata unconditionally so it survives regardless of load order. This
      # only matters for the on-demand schema generation in the test suite, so it is
      # installed from spec_helper rather than the gem's runtime load path.
      module AlwaysRegisterTypeHints
        def assign_type_information(attribute_name, attributes)
          attributes.each do |name, attrs|
            next unless name

            store_type(attribute_name, name, Typelizer::TypeParser.parse_declaration(attrs))
          end
        end
      end
    end
  end
end

Typelizer::DSL::ClassMethods.prepend(Spree::Api::TestingSupport::AlwaysRegisterTypeHints)
