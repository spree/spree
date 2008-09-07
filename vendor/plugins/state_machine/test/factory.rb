module Factory
  # Build actions for the model
  def self.build(model, &block)
    name = model.to_s.underscore
    
    define_method("#{name}_attributes", block)
    define_method("valid_#{name}_attributes") {|*args| valid_attributes_for(model, *args)}
    define_method("new_#{name}")              {|*args| new_record(model, *args)}
    define_method("create_#{name}")           {|*args| create_record(model, *args)}
  end
  
  # Get valid attributes for the model
  def valid_attributes_for(model, attributes = {})
    name = model.to_s.underscore
    send("#{name}_attributes", attributes)
    attributes
  end
  
  # Build an unsaved record
  def new_record(model, *args)
    model.new(valid_attributes_for(model, *args))
  end
  
  # Build and save/reload a record
  def create_record(model, *args)
    record = new_record(model, *args)
    record.save!
    record.reload
    record
  end
  
  build AutoShop do |attributes|
    attributes.reverse_merge!(
      :name => "Joe's Auto Body",
      :num_customers => 0
    )
  end
  
  build Car do |attributes|
    valid_vehicle_attributes(attributes)
  end
  
  build Highway do |attributes|
    attributes.reverse_merge!(
      :name => 'Route 66'
    )
  end
  
  build Motorcycle do |attributes|
    valid_car_attributes(attributes)
  end
  
  build Switch do |attributes|
    attributes.reverse_merge!(
      :state => 'off'
    )
  end
  
  build ToggleSwitch do |attributes|
    attributes.reverse_merge!(
      :state => 'off'
    )
  end
  
  build Vehicle do |attributes|
    attributes[:highway] = create_highway unless attributes.include?(:highway)
    attributes[:auto_shop] = create_auto_shop unless attributes.include?(:auto_shop)
    attributes.reverse_merge!(
      :seatbelt_on => false,
      :insurance_premium => 50
    )
  end
end
