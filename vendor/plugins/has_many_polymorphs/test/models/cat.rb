class Cat < ActiveRecord::Base
  # STI base class
  self.inheritance_column = 'cat_type'
end

