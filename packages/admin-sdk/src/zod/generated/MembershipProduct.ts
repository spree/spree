// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MembershipProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  thumbnail_url: z.string().nullable(),
});

export type MembershipProduct = z.infer<typeof MembershipProductSchema>;
