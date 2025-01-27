export const customersWorkbook = {
  name: "Customers",
  sheets: [
    {
      name: 'Customers',
      slug: 'customers',
      fields: [
        {
          key: "first_name",
          label: "First name",
          type: "string"
        },
        {
          key: "last_name",
          label: "Last name",
          type: "string"
        },
        {
          key: "email",
          label: "Email",
          type: "string",
          constraints: [
            { type: "required" }
          ]
        },
        {
          key: "phone",
          label: "Phone",
          type: "string"
        },
        {
          key: "accepts_email_marketing",
          label: "Accepts email marketing",
          type: "boolean"
        },
        {
          key: "accepts_sms_marketing",
          label: "Accepts SMS marketing",
          type: "boolean"
        },
        {
          key: "company",
          label: "Company",
          type: "string"
        },
        {
          key: "address1",
          label: "Address 1",
          type: "string"
        },
        {
          key: "address2",
          label: "Address 2",
          type: "string"
        },
        {
          key: "zip",
          label: "Zip",
          type: "string"
        },
        {
          key: "city",
          label: "City",
          type: "string"
        },
        {
          key: "province",
          label: "Province",
          type: "string"
        },
        {
          key: "province_code",
          label: "Province code",
          type: "string"
        },
        {
          key: "country",
          label: "Country",
          type: "string"
        },
        {
          key: "country_code",
          label: "Country code",
          type: "string"
        },
        {
          key: "note",
          label: "Note",
          type: "string"
        },
        {
          key: "tax_exempt",
          label: "Tax exempt",
          type: "boolean"
        }
      ]
    }
  ],
  actions: [
    {
      operation: "submitData",
      mode: "foreground",
      label: "Submit data",
      primary: true,
      constraints: [
        { type: 'hasData' }
      ]
    },
  ],
  settings: {
    track_changes: true
  }
}
