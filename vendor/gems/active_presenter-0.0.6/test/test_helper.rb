require File.dirname(__FILE__)+'/../lib/active_presenter'
require 'expectations'
require 'logger'

ActiveRecord::Base.configurations = {'sqlite3' => {:adapter => 'sqlite3', :database => ':memory:'}}
ActiveRecord::Base.establish_connection('sqlite3')

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN

ActiveRecord::Schema.define(:version => 0) do
  create_table :users do |t|
    t.boolean :admin,    :default => false
    t.string  :login,    :default => ''
    t.string  :password, :default => ''
  end
  
  create_table :accounts do |t|
    t.string :subdomain, :default => ''
    t.string :title,     :default => ''
  end
  
  create_table :addresses do |t|
    t.string :street
  end

  create_table :account_infos do |t|
    t.string :info
  end
end

class User < ActiveRecord::Base
  validates_presence_of :login, :password
  attr_accessible :login, :password
  attr_accessor   :password_confirmation
end
class Account < ActiveRecord::Base; end
class Address < ActiveRecord::Base; end
class AccountInfo < ActiveRecord::Base; end

class SignupPresenter < ActivePresenter::Base
  presents :account, :user
end

class EndingWithSPresenter < ActivePresenter::Base
  presents :address
end

class CantSavePresenter < ActivePresenter::Base
  presents :address
  
  before_save :halt
  
  def halt; false; end
end

class AfterSavePresenter < ActivePresenter::Base
  presents :address
  
  after_save :set_street
  
  def set_street
    address.street = 'Some Street'
  end
end

class SamePrefixPresenter < ActivePresenter::Base
  presents :account, :account_info
end

def hash_for_user(opts = {})
  {:login => 'jane', :password => 'seekrit' }.merge(opts)
end

