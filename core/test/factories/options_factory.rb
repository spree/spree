Factory.define :option_value do |f|
  f.name "Size"
  f.presentation "S"
  f.association :option_type
end

Factory.define :option_type do |f|
  f.name "foo-size"
  f.presentation "Size"
end