import fs from 'node:fs'

const TASKS_DIR = new URL('../tasks/', import.meta.url)

// Every file in tasks/ default-exports one task: { id, title, project, timeoutMinutes, prompt, check }.
export async function loadTasks() {
  const files = fs
    .readdirSync(TASKS_DIR)
    .filter((file) => file.endsWith('.mjs'))
    .sort()
  const tasks = []
  for (const file of files) {
    const { default: task } = await import(new URL(file, TASKS_DIR))
    tasks.push(task)
  }
  return tasks
}
