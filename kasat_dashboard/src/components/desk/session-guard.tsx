"use client";

import { useEffect } from "react";

import { getSupabaseBrowserClient, isSupabaseConfigured } from "@/lib/supabase";

/**
 * Back-forward cache can restore a staff page after logout. If that happens,
 * recheck the session and leave when it is gone.
 */
export function SessionGuard() {
  useEffect(() => {
    if (!isSupabaseConfigured()) return;

    function onPageShow(event: PageTransitionEvent) {
      if (!event.persisted) return;
      void getSupabaseBrowserClient()
        .auth.getUser()
        .then(({ data }) => {
          if (!data.user) window.location.assign("/login");
        })
        .catch(() => {
          window.location.assign("/login");
        });
    }

    window.addEventListener("pageshow", onPageShow);
    return () => window.removeEventListener("pageshow", onPageShow);
  }, []);

  return null;
}
