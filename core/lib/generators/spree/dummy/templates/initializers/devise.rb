if Object.const_defined?("Devise")
  Devise.secret_key = "<%= SecureRandom.hex(50) %>"
end