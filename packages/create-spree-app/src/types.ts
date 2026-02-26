export type SetupMode = 'full-stack' | 'backend-only'

export type PackageManager = 'npm' | 'yarn' | 'pnpm'

export interface ScaffoldOptions {
  directory: string
  mode: SetupMode
  sampleData: boolean
  start: boolean
  packageManager: PackageManager
  port: number
}
