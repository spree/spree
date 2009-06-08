module PreferenceFactory
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
    record.stub!(:valid?, :return => true)
    record.save!
    record.reload
    record
  end
  
  build Product do |attributes|
    attributes.reverse_merge!(
      :name => 'Porsche'
    )
  end
  
  build Preference do |attributes|
    attributes[:owner] = mock_model(User) unless attributes.include?(:owner)
    attributes.reverse_merge!(
      :attribute => 'notifications',
      :value => false
    )
  end

  build User do |attributes|
    attributes.reverse_merge!(
      :email => "email_name"
    )
  end

  build AppConfiguration do |attributes|
    attributes.reverse_merge!(
      :name => "Default Configuration"
    )
  end
end
