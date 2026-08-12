# The digital product itself is a normal row in products.csv (product_type
# "Digital"), so the import gives it the digital delivery profile — the product
# type stamps it at creation. The one thing a CSV row cannot carry is the file
# buyers download, so that is all this step does: attach a PDF to the imported
# product's default variant.
store = Spree::Store.default

product = Spree::Product.find_by(store: store, slug: 'the-spree-commerce-handbook')

if product && !product.default_variant.digital_assets.exists?
  # A minimal valid PDF, built in memory so seeding stays offline. The customer
  # receives this file through their download link.
  pdf = +"%PDF-1.4\n"
  pdf << "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
  pdf << "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
  pdf << "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj\n"
  pdf << "trailer<</Root 1 0 R>>\n%%EOF\n"

  asset = Spree::DigitalAsset.new(variant: product.default_variant)
  asset.attachment.attach(
    io: StringIO.new(pdf),
    filename: 'the-spree-commerce-handbook.pdf',
    content_type: 'application/pdf'
  )
  asset.save!
end
