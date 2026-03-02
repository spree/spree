export type ProjectMode = 'docker'

export interface ProjectContext {
  mode: ProjectMode
  projectDir: string
  port: number
}
