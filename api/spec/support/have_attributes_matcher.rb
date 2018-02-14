
RSpec::Matchers.define :have_attributes do |expected_attributes|
  match do |actual|
    # actual is a Hash object representing an object, like this:
    # { "name" => "Product #1" }
    actual_attributes = actual.keys.map(&:to_sym)
    expected_attributes.map(&:to_sym).all? { |attr| actual_attributes.include?(attr) }
  end
end
