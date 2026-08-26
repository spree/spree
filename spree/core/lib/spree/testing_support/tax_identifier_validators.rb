# The validator registry is process-global and core registers a default for
# +eu_vat+, so a spec that swaps one in has to put back whatever was there
# rather than deleting its own entry — deleting strips core's default (or an
# installed provider gem's) for every example that follows, which shows up as
# an unrelated spec failing under some seeds and not others.
#
# Lives in testing_support rather than core's spec/support because the API
# suite registers validators too, and the default it would delete is shared.
module TaxIdentifierValidatorHelpers
  # @param kind [String] the registration kind, e.g. 'eu_vat'
  # @param class_name [String, nil] validator to register for the block; nil
  #   deregisters the kind for its duration
  def with_tax_identifier_validator(kind, class_name)
    previous = Spree.tax_identifier_validators[kind]
    had_previous = Spree.tax_identifier_validators.key?(kind)

    if class_name.nil?
      Spree.tax_identifier_validators.delete(kind)
    else
      Spree.tax_identifier_validators[kind] = class_name
    end

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
