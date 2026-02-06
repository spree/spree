Alba.backend = :oj
Alba.inflector = :active_support

# Custom types
Alba.register_type :iso8601, converter: ->(time) { time&.iso8601(3) }, auto_convert: true
