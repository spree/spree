class Contact < ActiveRecord::Base
  def fullname
    firstname + ' ' + lastname
  end
end