class RakeUtil

  def self.add_marker(msg)
    puts "#"*30 + " #{msg} " + '#'*30
  end

  def self.warning(msg)
    puts "#"*50
    puts msg
    puts "#"*50
  end

  def self.execute(cmd)
    puts cmd
    system cmd
  end

end

