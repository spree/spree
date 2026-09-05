import { setupServer } from 'msw/node'

/**
 * Shared MSW server. Handlers are registered per test with `server.use`, since
 * what these tests assert is the request the client makes rather than any
 * particular response body.
 */
export const server = setupServer()
