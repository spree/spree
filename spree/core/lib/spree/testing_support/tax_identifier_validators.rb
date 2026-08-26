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
  # @param class_name [String] validator to register for the block
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

  # A structurally valid EU VAT number, by position in the fixture.
  #
  # Core format-checks +eu_vat+, so specs cannot invent numbers — the check
  # digit puts valid ones at irregular intervals. Distinct indexes give
  # distinct numbers, which is what lets an example prove WHICH registration
  # won. Wraps, so an owner needing more than the fixture holds would repeat a
  # number and hit the uniqueness validation instead.
  #
  # @param index [Integer] any counter; wraps around the fixture
  # @return [String]
  def eu_vat_number(index)
    EU_VAT_NUMBERS[index.to_i % EU_VAT_NUMBERS.size]
  end
  # Callable on the module too, for the factory — FactoryBot blocks run outside
  # RSpec example scope, so they cannot reach an included helper.
  module_function :eu_vat_number
  public :eu_vat_number

  EU_VAT_NUMBERS = Spree::Core::Engine.root
                                      .join('spec', 'fixtures', 'files', 'eu_vat_numbers.txt')
                                      .readlines(chomp: true)
                                      .grep_v(/\A\s*(#|\z)/)
                                      .freeze
end

RSpec.configure do |config|
  config.include TaxIdentifierValidatorHelpers
end
