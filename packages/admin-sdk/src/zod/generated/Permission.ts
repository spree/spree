// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PermissionSchema = z.object({
  key: z.string(),
  resource: z.string(),
  kind: z.string(),
  group: z.string(),
  group_label: z.string(),
  label: z.string(),
  description: z.string(),
});

export type Permission = z.infer<typeof PermissionSchema>;
