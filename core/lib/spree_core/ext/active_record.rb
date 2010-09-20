module ActiveRecord::Persistence

  # Update attributes of a record in the database without callbacks, validations etc.
  def update_attributes_without_callbacks(attributes)
    self.send(:attributes=, attributes, false)
    self.class.update_all(attributes, { :id => id })
  end

  # Update a single attribute in the database
  def update_attribute_without_callbacks(name, value)
    send("#{name}=", value)
    update_attributes_without_callbacks(name => value)
  end

end
