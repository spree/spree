class UserFilter < ActiveRecord::Base
  has_no_table

  column :email, :string

end