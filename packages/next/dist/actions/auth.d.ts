import { StoreUser } from '@spree/sdk';

/**
 * Login with email and password.
 * Automatically associates any guest cart with the authenticated user.
 */
declare function login(email: string, password: string): Promise<{
    success: boolean;
    user?: {
        id: string;
        email: string;
        first_name?: string | null;
        last_name?: string | null;
    };
    error?: string;
}>;
/**
 * Register a new customer account.
 * Automatically associates any guest cart with the new account.
 */
declare function register(email: string, password: string, passwordConfirmation: string): Promise<{
    success: boolean;
    user?: {
        id: string;
        email: string;
        first_name?: string | null;
        last_name?: string | null;
    };
    error?: string;
}>;
/**
 * Logout the current user.
 */
declare function logout(): Promise<void>;
/**
 * Get the currently authenticated customer. Returns null if not logged in.
 */
declare function getCustomer(): Promise<StoreUser | null>;
/**
 * Update the current customer's profile.
 */
declare function updateCustomer(data: {
    first_name?: string;
    last_name?: string;
    email?: string;
}): Promise<StoreUser>;

export { getCustomer, login, logout, register, updateCustomer };
