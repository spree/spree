class CssPoint < ActiveRecord::Base
  validates_presence_of :theme_id
  validates_presence_of :key
  validates_presence_of :value
  belongs_to :theme
end
