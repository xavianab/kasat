import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

type PendingCookie = { name: string; value: string; options: CookieOptions };

/**
 * Fixture mode when Supabase env is unset. When it is set, every page except
 * /login requires a real session from auth.getUser(). Cookie names alone are
 * not treated as proof of a session.
 */
function isStaticAsset(path: string) {
  return (
    path.startsWith("/_next/") ||
    path === "/favicon.ico" ||
    /\.(?:svg|png|jpg|jpeg|gif|webp|ico)$/i.test(path)
  );
}

function noStore(response: NextResponse) {
  response.headers.set("Cache-Control", "no-store");
  return response;
}

export async function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  if (isStaticAsset(path)) return NextResponse.next();

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) return NextResponse.next();

  let response = NextResponse.next({ request });
  const pending: PendingCookie[] = [];

  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: PendingCookie[]) {
        pending.splice(0, pending.length, ...cookiesToSet);
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const { data } = await supabase.auth.getUser();
  const user = data.user;
  const isLogin = path === "/login";

  if (!user && !isLogin) {
    const redirect = NextResponse.redirect(new URL("/login", request.url));
    pending.forEach(({ name, value, options }) => redirect.cookies.set(name, value, options));
    return noStore(redirect);
  }

  if (user && isLogin) {
    const redirect = NextResponse.redirect(new URL("/queues/unclaimed", request.url));
    pending.forEach(({ name, value, options }) => redirect.cookies.set(name, value, options));
    return noStore(redirect);
  }

  return noStore(response);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)"],
};
