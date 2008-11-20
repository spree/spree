class Image < Asset
  has_attached_file :attachment, :styles => { :mini => '48x48>', :small => '100x100>', :product => '240x240>' }, :default_style => :product
end