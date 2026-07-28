import { InviteGuestView } from "@/components/frame/invite-guest-view";
import { defaultLocale, isLocale, type Locale } from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string; code: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function InviteGuestPage({ params }: Props) {
  const { locale: raw, code: rawCode } = await params;
  const locale: Locale = isLocale(raw) ? raw : defaultLocale;
  const code = String(rawCode ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");

  if (code.length !== 8) {
    return (
      <main style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
        <h1>{locale === "zh" ? "无效的邀请链接" : "Invalid invite link"}</h1>
        <p lang={locale}>{locale === "zh" ? "此邀请码无效。" : "This invite code is not valid."}</p>
      </main>
    );
  }

  return <InviteGuestView code={code} />;
}
