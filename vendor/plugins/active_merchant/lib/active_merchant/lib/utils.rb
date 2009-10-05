require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Utils #:nodoc:
    def generate_unique_id
      md5 = Digest::MD5.new
      now = Time.now
      md5 << now.to_s
      md5 << String(now.usec)
      md5 << String(rand(0))
      md5 << String($$)
      md5 << self.class.name
      md5.hexdigest
    end
    
    module_function :generate_unique_id
  end
end