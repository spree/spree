class Setting
  attr :setting
  def initialize
    @data = Spree::Config.get
  end

  def update_attributes(hash)
    if hash
      hash.each do |k,v|
        Spree::Config.set({k => v})
      end
      return true
    else
      return false
    end
  end
end
