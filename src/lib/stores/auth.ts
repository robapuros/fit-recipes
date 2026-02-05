import { writable } from 'svelte/store';
import type { User, Session } from '@supabase/supabase-js';
import { supabase, type Profile } from '$lib/supabase';

interface AuthState {
  user: User | null;
  profile: Profile | null;
  session: Session | null;
  loading: boolean;
}

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>({
    user: null,
    profile: null,
    session: null,
    loading: true
  });

  return {
    subscribe,
    
    async initialize() {
      // Get initial session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session?.user) {
        const profile = await this.fetchProfile(session.user.id);
        set({ user: session.user, profile, session, loading: false });
      } else {
        set({ user: null, profile: null, session: null, loading: false });
      }

      // Listen for auth changes
      supabase.auth.onAuthStateChange(async (event, session) => {
        if (session?.user) {
          const profile = await this.fetchProfile(session.user.id);
          set({ user: session.user, profile, session, loading: false });
        } else {
          set({ user: null, profile: null, session: null, loading: false });
        }
      });
    },

    async fetchProfile(userId: string): Promise<Profile | null> {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();
      
      if (error) {
        console.error('Error fetching profile:', error);
        return null;
      }
      return data;
    },

    async signIn(email: string) {
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: {
          emailRedirectTo: window.location.origin
        }
      });
      return { error };
    },

    async signInWithPassword(email: string, password: string) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      return { data, error };
    },

    async signOut() {
      const { error } = await supabase.auth.signOut();
      if (!error) {
        set({ user: null, profile: null, session: null, loading: false });
      }
      return { error };
    }
  };
}

export const auth = createAuthStore();
