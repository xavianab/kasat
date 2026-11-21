import type { NextConfig } from "next";

// Fail closed: a production build must never ship with demo fixtures enabled.
if (
  process.env.NODE_ENV === "production" &&
  process.env.NEXT_PUBLIC_DEMO_MODE === "true"
) {
  throw new Error(
    "NEXT_PUBLIC_DEMO_MODE=true is not allowed in a production build. Unset it and rebuild.",
  );
}

const config: NextConfig = {
  reactStrictMode: true,
  // The dashboard renders survivor payloads. Nothing here should be indexed,
  // embedded, or referred out with a referrer header.
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
        ],
      },
    ];
  },
};

export default config;
