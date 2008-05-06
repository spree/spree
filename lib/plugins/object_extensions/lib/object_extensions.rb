class Object
  def self.descendants
    subclasses_of(self)
  end
end