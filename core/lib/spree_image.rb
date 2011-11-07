module SpreeImage
  def self.options
    @options ||= {
      :styles => { :mini => '48x48>', :small => '100x100>', :product => '240x240>', :large => '600x600>' },
      :default_style => :product,
      :url => "/spree/products/:id/:style/:basename.:extension",
      :path => ":rails_root/public/spree/products/:id/:style/:basename.:extension"
    }
  end
  def self.options=(options)
    @options = options
  end
end