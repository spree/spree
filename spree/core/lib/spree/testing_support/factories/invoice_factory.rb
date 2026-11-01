FactoryBot.define do
  factory :invoice, class: Spree::Invoice do
    association :order, factory: :completed_order_with_totals
    store { order&.store || seller_payout&.store }
    issuer { order ? Spree::Invoice.issuer_for(order) : store }
    kind { 'invoice' }
    source { 'uploaded' }
    sequence(:number) { |n| "INV-2026-#{n.to_s.rjust(4, '0')}" }
    issued_on { Date.current }
    currency { order&.currency || 'USD' }
    total { 100 }
    net_total { 81.30 }
    tax_total { 18.70 }

    after(:build) do |invoice|
      next if invoice.file.attached?

      invoice.file.attach(
        io: StringIO.new("%PDF-1.4\n%invoice\n%%EOF\n"),
        filename: "#{invoice.number}.pdf",
        content_type: 'application/pdf'
      )
    end

    trait :credit_note do
      kind { 'credit_note' }
      total { -20 }
      net_total { -16.26 }
      tax_total { -3.74 }
      original_invoice { association(:invoice, order: order) }
    end

    trait :receipt do
      kind { 'receipt' }
    end

    trait :commission do
      order { nil }
      association :seller_payout
    end

    trait :sent do
      sent_at { 1.hour.ago }
    end
  end

  factory :invoice_request, class: Spree::InvoiceRequest do
    association :order, factory: :completed_order_with_totals
    store { order.store }
    status { 'open' }
    company_name { 'Acme GmbH' }
    tax_id { 'DE123456789' }
  end

  factory :order_document, class: Spree::OrderDocument do
    association :order, factory: :completed_order_with_totals
    store { order.store }
    label { 'Signed purchase order' }
    customer_visible { false }

    after(:build) do |document|
      next if document.file.attached?

      document.file.attach(io: StringIO.new("%PDF-1.4\n%doc\n%%EOF\n"), filename: 'po.pdf', content_type: 'application/pdf')
    end
  end
end
