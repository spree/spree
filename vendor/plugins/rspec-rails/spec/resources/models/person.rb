class Person < ActiveRecord::Base
  has_many :animals do
    def pups
      find(:all, :conditions => 'age < 1')
    end
    def adults
      find(:all, :conditions => 'age >= 1')
    end
  end
  validates_presence_of :name
  
  def add_animal animal
    animal.person = self
    animals << animal
    animal.save
  end
    
end
