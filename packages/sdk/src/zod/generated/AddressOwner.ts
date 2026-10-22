// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AddressOwnerSchema = z.object({
  id: z.string(),
  type: z.string(),
  name: z.string().nullable(),
});

export type AddressOwner = z.infer<typeof AddressOwnerSchema>;
