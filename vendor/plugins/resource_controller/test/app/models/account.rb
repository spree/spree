class Account < ActiveRecord::Base
  has_many :photos
  has_many :options
end
