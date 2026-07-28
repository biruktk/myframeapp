"use client";

import { useCallback, useEffect, useState } from "react";

type InviteInfo = {
  ok: boolean;
  frameName?: string;
  frameMac?: string;
  inviteUrl?: string;
  error?: string;
};

type Props = {
  code: string;
};

type Lang = "zh" | "en";

const COPY: Record<Lang, Record<string, string>> = {
  zh: {
    title: "发送照片",
    subtitle: "您收到一个照片发送邀请，请选择并上传照片至艺术相框。",
    frameLabel: "相框设备",
    loading: "正在加载邀请信息…",
    invalid: "此邀请链接无效或已过期。",
    loadError: "无法加载邀请信息，请检查网络连接。",
    uploadBtn: "选择照片并发送",
    sending: "发送中…",
    successDelivered: "照片已成功发送！稍后将显示在相框上。",
    successReceived: "照片已接收！相框在线后将立即显示。",
    uploadError: "上传失败，请重试。",
    qrAlt: "邀请二维码",
  },
  en: {
    title: "Send a photo",
    subtitle: "You were invited to send a picture to a MyFrame device. Choose a photo below.",
    frameLabel: "Frame",
    loading: "Loading invite…",
    invalid: "This invite link is invalid or expired.",
    loadError: "Could not load invite. Check your connection.",
    uploadBtn: "Choose photo & send",
    sending: "Sending…",
    successDelivered: "Photo sent! It should appear on the frame shortly.",
    successReceived: "Photo received! The frame will show it when online.",
    uploadError: "Upload failed. Please try again.",
    qrAlt: "Invite QR code",
  },
};

function detectLocale(): Lang {
  if (typeof window === "undefined") return "zh";
  const params = new URLSearchParams(window.location.search);
  const lang = params.get("lang");
  if (lang === "zh") return "zh";
  if (lang === "en") return "en";
  const browserLang = (navigator.language || "").toLowerCase();
  if (browserLang.startsWith("zh")) return "zh";
  return "zh";
}

const API_BASE =
  typeof window !== "undefined" && window.location.hostname === "myframe.ink"
    ? "https://myframe.ink"
    : "http://128.241.231.234:3001";

export function InviteGuestView({ code }: Props) {
  const lang = detectLocale();
  const t = (key: string) => COPY[lang][key] ?? COPY.en[key] ?? key;

  const [info, setInfo] = useState<InviteInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`${API_BASE}/api/invite/${encodeURIComponent(code)}/info`);
        const data = (await res.json()) as InviteInfo;
        if (!cancelled) {
          if (!res.ok || !data.ok) {
            setError(t("invalid"));
          } else {
            setInfo(data);
          }
        }
      } catch {
        if (!cancelled) setError(t("loadError"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [code, t]);

  const onPickPhoto = useCallback(
    async (file: File | null) => {
      if (!file || !info?.ok) return;
      setUploading(true);
      setError(null);
      setMessage(null);
      try {
        const form = new FormData();
        form.append("photo", file, file.name || "photo.jpg");
        const res = await fetch(`${API_BASE}/api/invite/${encodeURIComponent(code)}/upload`, {
          method: "POST",
          body: form,
        });
        const data = (await res.json()) as { ok?: boolean; error?: string; delivered_to_frame?: boolean };
        if (!res.ok || !data.ok) {
          setError(data.error || t("uploadError"));
          return;
        }
        setMessage(data.delivered_to_frame ? t("successDelivered") : t("successReceived"));
      } catch {
        setError(t("uploadError"));
      } finally {
        setUploading(false);
      }
    },
    [code, info?.ok, t],
  );

  const qrSrc = `${API_BASE}/api/invite/${encodeURIComponent(code)}/qr`;

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#f5f5f5",
        fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
        padding: "24px 16px",
      }}
    >
      <div style={{ maxWidth: 420, margin: "0 auto" }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: "0 0 8px", color: "#111" }}>
          {t("title")}
        </h1>
        <p style={{ margin: "0 0 20px", color: "#666", fontSize: 14, lineHeight: 1.5 }}>
          {t("subtitle")}
        </p>

        {loading && <p style={{ color: "#666" }}>{t("loading")}</p>}

        {!loading && error && (
          <p style={{ color: "#dc2626", background: "#fef2f2", padding: 12, borderRadius: 8 }}>{error}</p>
        )}

        {!loading && info?.ok && (
          <>
            <div
              style={{
                background: "#fff",
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
                boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
              }}
            >
              <p style={{ margin: 0, fontSize: 13, color: "#888" }}>{t("frameLabel")}</p>
              <p style={{ margin: "4px 0 0", fontWeight: 700, fontSize: 16 }}>
                {info.frameName || info.frameMac}
              </p>
            </div>

            <div
              style={{
                background: "#fff",
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
                textAlign: "center",
                boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
              }}
            >
              <img src={qrSrc} alt={t("qrAlt")} width={200} height={200} style={{ display: "block", margin: "0 auto" }} />
              <p style={{ fontSize: 12, color: "#888", marginTop: 12, wordBreak: "break-all" }}>{info.inviteUrl}</p>
            </div>

            <label
              style={{
                display: "block",
                width: "100%",
                textAlign: "center",
                background: "#dc2626",
                color: "#fff",
                padding: "14px 20px",
                borderRadius: 10,
                fontWeight: 600,
                cursor: uploading ? "wait" : "pointer",
                opacity: uploading ? 0.7 : 1,
              }}
            >
              {uploading ? t("sending") : t("uploadBtn")}
              <input
                type="file"
                accept="image/*"
                style={{ display: "none" }}
                disabled={uploading}
                onChange={(e) => {
                  const f = e.target.files?.[0] ?? null;
                  void onPickPhoto(f);
                  e.target.value = "";
                }}
              />
            </label>

            {message && (
              <p style={{ color: "#15803d", marginTop: 16, textAlign: "center", fontSize: 14 }}>{message}</p>
            )}
            {error && (
              <p style={{ color: "#dc2626", marginTop: 16, textAlign: "center", fontSize: 14 }}>{error}</p>
            )}
          </>
        )}
      </div>
    </main>
  );
}
