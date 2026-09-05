// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ChannelSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string(),
  active: z.boolean(),
  default: z.boolean(),
  storefront_access: z.string(),
  guest_checkout: z.boolean(),
});

export type Channel = z.infer<typeof ChannelSchema>;
