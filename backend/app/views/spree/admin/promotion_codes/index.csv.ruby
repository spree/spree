CSV.generate do |csv|
  csv << ['Code']
  @promotion.codes.order(:id).each do |code|
    csv << [code.value]
  end
end
