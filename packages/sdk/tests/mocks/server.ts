import { setupServer } from 'msw/node';
import { handlers } from './handlers';
import { adminHandlers } from './admin-handlers';

export const server = setupServer(...handlers, ...adminHandlers);
