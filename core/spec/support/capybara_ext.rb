module CapybaraExt
  def page!
    save_and_open_page
  end
end

RSpec.configure do |c|
  c.include CapybaraExt
end
