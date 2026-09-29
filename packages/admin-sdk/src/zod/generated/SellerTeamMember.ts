// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerTeamMemberSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  full_name: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  avatar_url: z.string().nullable(),
});

export type SellerTeamMember = z.infer<typeof SellerTeamMemberSchema>;
