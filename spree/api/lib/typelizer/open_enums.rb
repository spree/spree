module Typelizer
  module OpenEnums
    # A `typelize` entry with `enum:` alone renders a closed union — the right
    # shape for a list nothing outside core can grow (units, match policies).
    # Adding `enum_type_name:` marks the list as one an extension may extend
    # (`has_status` values, `Spree::Fee::KINDS`): it becomes a named, exported
    # type whose union stays open, so client code comparing against an added
    # value still typechecks while every known value keeps its autocomplete.
    # The OpenAPI schema is unaffected and lists the built-in values either way.
    def enum_definition(...)
      definition = super
      definition && "#{definition} | (string & {})"
    end
  end
end

Typelizer::Property.prepend(Typelizer::OpenEnums)
