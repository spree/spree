Factory.define :calculator, :class => Calculator::FlatRate do |f|
  f.after_create do |c|
    c.set_preference(:amount, 10.0)
  end
end
