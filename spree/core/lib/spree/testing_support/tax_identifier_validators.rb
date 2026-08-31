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
    numbers = eu_vat_numbers
    numbers[index.to_i % numbers.size]
  end

  # The whole fixture, for a spec that needs a number DIFFERENT from one it
  # already holds — the factory sequence is global and never resets, so a fixed
  # index eventually collides with whatever the factory just produced.
  #
  # @return [Array<String>]
  def eu_vat_numbers
    TaxIdentifierValidatorHelpers.eu_vat_numbers
  end
  # Callable on the module too, for the factory — FactoryBot blocks run outside
  # RSpec example scope, so they cannot reach an included helper.
  module_function :eu_vat_number
  public :eu_vat_number

  # Read lazily rather than at load: the fixture ships in the gem, but a
  # consumer that vendors only lib/ would otherwise take down the whole
  # spec_helper on require instead of just the specs that need a number.
  def self.eu_vat_numbers
    @eu_vat_numbers ||= Spree::Core::Engine.root
                                           .join('spec', 'fixtures', 'files', 'eu_vat_numbers.txt')
                                           .readlines(chomp: true)
                                           .grep_v(/\A\s*(#|\z)/)
                                           .freeze
  end
end

RSpec.configure do |config|
  config.include TaxIdentifierValidatorHelpers
end
