// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminUserSchema } from './AdminUser';

export const MaintenanceTaskRunSchema = z.object({
  id: z.string(),
  status: z.string(),
  dry_run: z.boolean(),
  initiated_via: z.string(),
  tick_count: z.number(),
  tick_total: z.number().nullable(),
  error_class: z.string().nullable(),
  error_message: z.string().nullable(),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  task_name: z.string(),
  duration: z.number().nullable(),
  tallies: z.record(z.string(), z.number()),
  arguments: z.record(z.string(), z.unknown()),
  error_backtrace: z.string().nullable(),
  active: z.boolean(),
  store_id: z.string().nullable(),
  admin_user_id: z.string().nullable(),
  admin_user: AdminUserSchema.optional(),
});

export type MaintenanceTaskRun = z.infer<typeof MaintenanceTaskRunSchema>;
