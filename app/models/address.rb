class Address < ActiveRecord::Base
  belongs_to :user
  belongs_to :country
  belongs_to :state
  belongs_to :addressable, :polymorphic => true
  
  validates_presence_of :firstname
  validates_presence_of :lastname
  validates_presence_of :address1
  validates_presence_of :city
  validates_presence_of :state
  validates_presence_of :zipcode
  validates_presence_of :country
  validates_presence_of :phone
  
  def full_name
    self.firstname + " " + self.lastname
  end
end
