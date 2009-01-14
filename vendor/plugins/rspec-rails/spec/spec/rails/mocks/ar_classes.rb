class MockableModel < ActiveRecord::Base
  has_one :associated_model
end

class SubMockableModel < MockableModel
end

class AssociatedModel < ActiveRecord::Base
  belongs_to :mockable_model
end
