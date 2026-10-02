/** A problem in the file itself, reported against a YAML path. */
export class ConfigError extends Error {
  constructor(
    message: string,
    readonly path: string,
  ) {
    super(message)
    this.name = 'ConfigError'
  }
}

/** A reference to a natural key that exists neither in the file nor on the live instance. */
export class DanglingReferenceError extends ConfigError {
  constructor(section: string, key: string, path: string) {
    super(`${section} "${key}" is not declared in the file and does not exist on the store`, path)
    this.name = 'DanglingReferenceError'
  }
}
