# The validator registry is process-global. Specs that register one have to put
# back whatever was there before rather than deleting their own entry, or they
# strip a registration another spec (or an installed provider gem) relies on and
# make the suite order-dependent.
module TaxIdentifierValidatorHelpers
  def with_tax_identifier_validator(kind, class_name)
    previous = Spree.tax_identifier_validators[kind]
    had_previous = Spree.tax_identifier_validators.key?(kind)
    Spree.tax_identifier_validators[kind] = class_name

    yield
  ensure
    if had_previous
      Spree.tax_identifier_validators[kind] = previous
    else
      Spree.tax_identifier_validators.delete(kind)
    end
  end
end

RSpec.configure do |config|
  config.include TaxIdentifierValidatorHelpers
end
