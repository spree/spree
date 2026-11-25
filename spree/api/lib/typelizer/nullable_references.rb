module Typelizer
  # OpenAPI 3.0.3 reads `nullable: true` only beside a `type` in the same
  # schema, so the `allOf: [$ref]` plus `nullable: true` Typelizer writes for
  # a nullable association still rejects the null the API sends. The
  # reference becomes one branch of an `anyOf` whose other branch accepts
  # only null, the form OpenAPI 3.0.3 itself describes for this case.
  module NullableReferences
    # @param reference [Hash] a `$ref`, or an `allOf` of several
    # @param metadata [Hash] description and deprecation of the property
    # @return [Hash] a schema accepting the reference or null
    def self.wrap(reference, **metadata)
      { anyOf: [reference, { type: :object, nullable: true, enum: [nil] }] }.merge(metadata)
    end

    module Schema
      def property_schema(property, **options)
        schema = super
        return schema if v31?(options.fetch(:openapi_version, '3.0'))
        return schema unless schema.is_a?(Hash) && schema[:nullable] && schema[:allOf] && !schema.key?(:type)

        all_of = schema[:allOf]
        NullableReferences.wrap(all_of.one? ? all_of.first : { allOf: all_of }, **schema.except(:allOf, :nullable))
      end
    end
  end
end

Typelizer::OpenAPI.singleton_class.prepend(Typelizer::NullableReferences::Schema)
