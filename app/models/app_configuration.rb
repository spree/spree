class AppConfiguration < ActiveRecord::Base

  MAIL_AUTH = ['none', 'plain', 'login', 'cram_md5']
  SECURE_CONNECTION_TYPES = ['None','SSL','TLS']

  preference :enable_mail_delivery, :boolean, :default => false
  preference :mail_host, :string, :default => 'localhost'
  preference :mail_domain, :string, :default => 'localhost'
  preference :mail_port, :integer, :default => 25
  preference :mail_auth_type, :string, :default => MAIL_AUTH[0] 
  preference :mail_username, :string
  preference :mail_password, :string
  preference :secure_connection_type, :string, :default => SECURE_CONNECTION_TYPES[0] 
  preference :send_mails_as, :string
  preference :mail_copy_to, :string

  validates_presence_of :name

  named_scope :active, :conditions => { :active => true }

end
