import { NextResponse, type NextRequest } from "next/server";

/**
 * Dispatch is fixture-only today. When Supabase is configured, require a
 * session cookie before showing /dispatch so the service-role key is never
 * needed in the browser and the queue is not a public page.
 */
export function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const configured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
  if (!configured) {
    return NextResponse.next();
  }

  const isLogin = path === "/login" || path.startsWith("/auth");
  const isDispatch = path === "/dispatch" || path.startsWith("/dispatch/");
  if (!isDispatch || isLogin) {
    return NextResponse.next();
  }

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
  matcher: ["/dispatch/:path*"],
};
