export type PackageManager = 'npm' | 'yarn' | 'pnpm'

export interface ScaffoldOptions {
  directory: string
  storefront: boolean
  dashboard: boolean
  sampleData: boolean
  start: boolean
  packageManager: PackageManager
  port: number
}
