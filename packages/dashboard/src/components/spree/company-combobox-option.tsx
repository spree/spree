import type { Company } from '@spree/admin-sdk'

/** The ancestor breadcrumb shown under a company name in pickers and lists. */
export function formatCompanyAncestorPath(company: Company): string | undefined {
  if (company.ancestors.length === 0) return undefined
  return company.ancestors.map((ancestor) => ancestor.name).join(' / ')
}

/** Dropdown row for a company picker — name plus its place in the tree. */
export function CompanyComboboxOption({ company }: { company: Company }) {
  const path = formatCompanyAncestorPath(company)

  return (
    <div>
      <div className="font-medium">{company.name ?? company.id}</div>
      {path && <div className="text-muted-foreground text-xs">{path}</div>}
    </div>
  )
}
