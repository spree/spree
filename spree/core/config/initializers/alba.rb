Alba.backend = :oj_rails
Alba.inflector = :active_support

# Custom types
Alba.register_type :iso8601, converter: ->(time) { time&.iso8601(3) }, auto_convert: true
# Decimals and money rendered as their exact string form instead of JSON numbers
Alba.register_type :string, check: ->(value) { value.is_a?(String) }, converter: ->(value) { value.to_s }, auto_convert: true
