// supabase.js — Admin Panel Supabase Initialization
// Connects to the same Supabase project as the Flutter mobile app.

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://mfysompctaxldphbxvkv.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_BXemNj8edIkUZQ70h3LHvA_4Bl3iaan';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
export default supabase;
