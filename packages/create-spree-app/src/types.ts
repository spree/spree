export type PackageManager = 'npm' | 'yarn' | 'pnpm'

export interface ScaffoldOptions {
  directory: string
  storefront: boolean
  dashboard: boolean
  start: boolean
  packageManager: PackageManager
  port: number
  mailpitSmtpPort: number
  mailpitUiPort: number
}
