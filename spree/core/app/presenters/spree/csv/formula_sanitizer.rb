module Spree
  module CSV
    # Neutralizes CSV formula injection (CWE-1236 / OWASP "CSV Injection")
    # by prefixing cells that would otherwise be evaluated as a formula
    # when the exported file is opened in Excel, Google Sheets, LibreOffice,
    # or Numbers.
    #
    # The leading apostrophe is the OWASP-recommended marker — spreadsheets
    # render the cell as plain text without displaying the apostrophe.
    module FormulaSanitizer
      TRIGGERS = ["=", "+", "-", "@", "\t", "\r", "\n"].freeze

      module_function

      def cell(value)
        return value unless value.is_a?(String)
        return value if value.empty?
        return value unless TRIGGERS.include?(value[0])

        "'#{value}"
      end

      def row(values)
        values.map { |v| cell(v) }
      end
    end
  end
end
