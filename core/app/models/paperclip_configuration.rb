class PaperclipConfiguration < Configuration

  preference :url,           :string,  :default => '/:class/:attachment/:id/:style_:filename'
  preference :path,          :string,  :default => ':rails_root/public/assets/:class/:id/:style/:basename.:extension'
  preference :default_url,   :string,  :default => '/images/noimage/:style.png'
  preference :whiny,         :boolean, :default => false
  preference :storage,       :string,  :default => :filesystem
  preference :default_style, :symbol,  :default => :product
  preference :styles,        :hash,    :default => { :mini => '48x48>', :small => '100x100>', :product => '240x240>', :large => '600x600>' }

  validates :name, :presence => true, :uniqueness => true

end
