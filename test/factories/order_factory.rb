Factory.define(:order) do |record|
  # associations: 
  record.association(:user, :factory => :user)
end

###### ADD YOUR CODE BELOW THIS LINE #####
