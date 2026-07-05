export type PackageManager = 'npm' | 'yarn' | 'pnpm'

export interface ScaffoldOptions {
  directory: string
  storefront: boolean
  sampleData: boolean
  start: boolean
  packageManager: PackageManager
  port: number
}
