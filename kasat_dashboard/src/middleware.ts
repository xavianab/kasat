import { NextResponse, type NextRequest } from "next/server";

/**
 * The desk is fixture-only until Supabase is configured. When it is, require
 * a session cookie before showing staff pages. The check itself is unchanged:
 * a Supabase auth cookie, otherwise the login page.
 */
export function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const configured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
  if (!configured) return NextResponse.next();

  const isLogin = path === "/login" || path.startsWith("/auth");
  const isStaff =
    path.startsWith("/dispatch") ||
    path.startsWith("/queues") ||
    path.startsWith("/cases") ||
    path.startsWith("/reports") ||
    path.startsWith("/access-log") ||
    path.startsWith("/settings") ||
    path.startsWith("/account");
  if (!isStaff || isLogin) return NextResponse.next();

  const hasSession = request.cookies
    .getAll()
    .some((cookie) => cookie.name.includes("-auth-token") || cookie.name.startsWith("sb-"));
  if (!hasSession) {
    const redirect = request.nextUrl.clone();
    redirect.pathname = "/login";
    return NextResponse.redirect(redirect);
  }
  return NextResponse.next();
}

export const config = {
  matcher: [
    "/dispatch/:path*",
    "/queues/:path*",
    "/cases/:path*",
    "/reports/:path*",
    "/access-log/:path*",
    "/settings/:path*",
    "/account/:path*",
  ],
};
