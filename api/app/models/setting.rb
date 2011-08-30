class Setting
  attr :data
  def initialize
    @data = Spree::Config.get
  end
end
