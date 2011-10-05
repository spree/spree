class Setting
  attr :setting
  def initialize
    @setting = Spree::Config.get
  end

  def update_attributes(hash)
    if hash
      hash.each do |k,v|
        Spree::Config.set(k => v)
      end
      return true
    else
      return false
    end
  end

  def to_xml(options)
    self.setting.to_xml(:root => 'setting')
  end
end
