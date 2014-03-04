RSpec::Matchers.define :have_attributes do |expected_attributes|
  match do |actual|
    # actual is a Hash object representing an object, like this:
    # { "name" => "Product #1" }
    actual_attributes = actual.keys.map(&:to_sym)
    expected_attributes.map(&:to_sym).all? { |attr| actual_attributes.include?(attr) }
  end

   failure_message_for_should do |actual|
    expected = expected_attributes.map(&:to_sym)
    actual = actual.keys.map(&:to_sym)
    %Q{
  Expected keys: #{expected}
  Actual keys: #{actual}
  Diff: #{expected - actual}
      }
  end
end

