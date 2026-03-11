import { setupServer } from 'msw/node';
import { adminHandlers } from './admin-handlers';

export const server = setupServer(...adminHandlers);
