class String

  # see if string has any content
  def blank?; self.length.zero?; end
  
end

class NilClass
  def blank?
    true
  end
end
