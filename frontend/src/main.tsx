import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  ArrowDownToLine,
  ArrowRight,
  ArrowUpRight,
  Check,
  CheckCheck,
  ChevronRight,
  Clock3,
  FileText,
  Files,
  History,
  LayoutDashboard,
  LogOut,
  Plus,
  Search,
  ShieldCheck,
  Sparkles,
  Upload,
  X,
} from "lucide-react";
import "./styles.css";

type User = {
  demo: boolean;
  name: string;
  email: string;
  workspace: string;
  role: "reviewer" | "viewer";
};
type Field = {
  id: number;
  key: string;
  label: string;
  value: string | null;
  evidence: string | null;
  page: number | null;
  review_state: "pending" | "accepted" | "omitted";
  note: string | null;
  uncertainty: string | null;
};
type Doc = {
  extraction_mode: "local_rules" | "live_ai";
  extraction_metadata: { model?: string };
  id: number;
  title: string;
  filename: string;
  status: "draft" | "approved";
  revision: number;
  created_at: string;
  approved_at: string | null;
  page_count: number;
  field_count: number;
  reviewed_count: number;
  missing_count: number;
  pages?: { number: number; text: string }[];
  fields?: Field[];
  events?: {
    id: number;
    action: string;
    actor: string;
    created_at: string;
    details: {
      field?: string;
      before?: { value: string };
      after?: { value: string; note: string; review_state: string };
    };
  }[];
};
let token = sessionStorage.getItem("clausedesk.token") || "";
async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch("/api" + path, {
    ...options,
    headers: {
      ...(options.body instanceof FormData
        ? {}
        : { "Content-Type": "application/json" }),
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error || "Something went wrong. Please try again.");
  }
  return response.status === 204 ? (undefined as T) : response.json();
}
const date = (value: string) =>
  new Date(value).toLocaleDateString("en", { month: "short", day: "numeric" });
function Brand() {
  return (
    <div className="brand">
      <span className="brand-icon">
        <Files size={21} />
      </span>
      Clause<span>Desk</span>
      <small>WORKSPACE</small>
    </div>
  );
}

function App() {
  const [capabilities, setCapabilities] = useState({
    demo: false,
    live_ai: false,
  });
  const [extracting, setExtracting] = useState(false);
  const [aiConsent, setAiConsent] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [booting, setBooting] = useState(Boolean(token));
  const [docs, setDocs] = useState<Doc[]>([]);
  const [selected, setSelected] = useState<Doc | null>(null);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [modal, setModal] = useState(false);
  const [history, setHistory] = useState(false);
  const [activeField, setActiveField] = useState<number | null>(null);
  const [loadingDocument, setLoadingDocument] = useState(false);
  const selectionRequest = useRef(0);
  const [email, setEmail] = useState("reviewer@clausedesk.test");
  const [password, setPassword] = useState("");
  const [title, setTitle] = useState("");
  const [file, setFile] = useState<File | null>(null);

  useEffect(() => {
    api<typeof capabilities>("/capabilities")
      .then(setCapabilities)
      .catch(() => {});
  }, []);
  useEffect(() => {
    setAiConsent(false);
  }, [selected?.id]);
  useEffect(() => {
    if (token)
      api<{ user: User }>("/session")
        .then((data) => setUser(data.user))
        .catch(() => {
          token = "";
          sessionStorage.removeItem("clausedesk.token");
        })
        .finally(() => setBooting(false));
  }, []);
  useEffect(() => {
    if (user) refresh().catch((e) => setError(e.message));
  }, [user]);
  useEffect(() => {
    if (activeField !== null)
      document
        .querySelector(`[data-source-field="${activeField}"]`)
        ?.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }, [activeField]);
  useEffect(() => {
    if (!modal) return;
    const previous = document.activeElement as HTMLElement | null;
    function keydown(e: KeyboardEvent) {
      if (e.key === "Escape" && !busy) setModal(false);
      if (e.key !== "Tab") return;
      const nodes = Array.from(
        document.querySelectorAll<HTMLElement>(
          '[role="dialog"] button:not(:disabled), [role="dialog"] input:not(:disabled)',
        ),
      );
      const first = nodes[0],
        last = nodes[nodes.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last?.focus();
      }
      if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first?.focus();
      }
    }
    document.addEventListener("keydown", keydown);
    return () => {
      document.removeEventListener("keydown", keydown);
      previous?.focus();
    };
  }, [modal, busy]);
  async function refresh() {
    const data = await api<{ documents: Doc[] }>("/documents");
    setDocs(data.documents);
  }
  async function openDocument(id: number) {
    if (busy) return;
    const request = ++selectionRequest.current;
    setLoadingDocument(true);
    setError("");
    setActiveField(null);
    setHistory(false);
    try {
      const data = await api<Doc>(`/documents/${id}`);
      if (request === selectionRequest.current) setSelected(data);
    } catch (e) {
      if (request === selectionRequest.current) setError((e as Error).message);
    } finally {
      if (request === selectionRequest.current) setLoadingDocument(false);
    }
  }
  async function run(task: () => Promise<void>) {
    setBusy(true);
    setError("");
    try {
      await task();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function login(event: React.FormEvent) {
    event.preventDefault();
    await run(async () => {
      const data = await api<{ token: string; user: User }>("/session", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });
      token = data.token;
      sessionStorage.setItem("clausedesk.token", token);
      setUser(data.user);
      setPassword("");
    });
  }
  async function tryDemo() {
    await run(async () => {
      const data = await api<{ token: string; user: User }>("/demo", {
        method: "POST",
      });
      token = data.token;
      sessionStorage.setItem("clausedesk.token", token);
      setUser(data.user);
    });
  }
  async function extract() {
    if (!selected || !aiConsent) return;
    const id = selected.id;
    setExtracting(true);
    await run(async () => {
      const doc = await api<Doc>(`/documents/${id}/extract`, {
        method: "POST",
        body: JSON.stringify({ revision: selected.revision }),
      });
      setSelected(doc);
      await refresh();
    });
    setExtracting(false);
  }
  async function logout() {
    await run(async () => {
      await api("/session", { method: "DELETE" });
      token = "";
      sessionStorage.removeItem("clausedesk.token");
      setUser(null);
      setDocs([]);
      setSelected(null);
    });
  }
  async function sample() {
    await run(async () => {
      const doc = await api<Doc>("/documents/sample", { method: "POST" });
      setSelected(doc);
      setModal(false);
      await refresh();
    });
  }
  async function upload(event: React.FormEvent) {
    event.preventDefault();
    if (!file) return;
    await run(async () => {
      const body = new FormData();
      body.append("title", title);
      body.append("file", file);
      const doc = await api<Doc>("/documents", { method: "POST", body });
      setSelected(doc);
      setModal(false);
      setTitle("");
      setFile(null);
      await refresh();
    });
  }
  async function review(
    field: Field,
    value: string,
    note: string,
    state: string,
  ) {
    if (!selected) return;
    await run(async () => {
      const doc = await api<Doc>(
        `/documents/${selected.id}/fields/${field.id}`,
        {
          method: "PATCH",
          body: JSON.stringify({
            revision: selected.revision,
            field: { value, note, review_state: state },
          }),
        },
      );
      setSelected(doc);
      await refresh();
    });
  }
  async function approve() {
    if (!selected) return;
    await run(async () => {
      setSelected(
        await api<Doc>(`/documents/${selected.id}/approve`, {
          method: "POST",
          body: JSON.stringify({ revision: selected.revision }),
        }),
      );
      await refresh();
    });
  }
  async function download() {
    if (!selected) return;
    await run(async () => {
      const response = await fetch(`/api/documents/${selected.id}/export`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) throw new Error((await response.json()).error);
      const url = URL.createObjectURL(await response.blob());
      const a = document.createElement("a");
      a.href = url;
      a.download = `clausedesk-${selected.id}-review.csv`;
      a.click();
      URL.revokeObjectURL(url);
    });
  }
  const canReview = user?.role === "reviewer";
  const visible = docs.filter(
    (d) =>
      (filter === "all" || d.status === filter) &&
      `${d.title} ${d.filename}`.toLowerCase().includes(query.toLowerCase()),
  );
  const approved = docs.filter((d) => d.status === "approved").length;
  if (booting) return <div className="boot">Opening your workspace…</div>;
  if (!user)
    return (
      <div className="login">
        <section className="login-story">
          <Brand />
          <div>
            <div className="eyebrow">FROM DOCUMENT TO DECISION</div>
            <h1>
              Every decision.
              <br />
              Backed by evidence.
            </h1>
            <p>
              A considered workspace for reviewing contract facts, keeping the
              source close and your decisions clear.
            </p>
            <div className="story-proof">
              <ShieldCheck size={20} /> Human-reviewed. Traceable. Ready to
              share.
            </div>
          </div>
          <span className="login-foot">
            ClauseDesk / Independent portfolio demo
          </span>
        </section>
        <section className="login-form">
          <div className="eyebrow">WELCOME BACK</div>
          <h2>Open your workspace</h2>
          <p>Sign in to review your team's agreements.</p>
          <form onSubmit={login}>
            <label>
              Email address
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="username"
              />
            </label>
            <label>
              Password
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />
            </label>
            {error && (
              <div role="alert" className="error">
                {error}
              </div>
            )}
            <button className="primary" disabled={busy}>
              Enter workspace <ArrowRight size={17} />
            </button>
          </form>
          {capabilities.demo && (
            <button
              className="secondary full"
              onClick={tryDemo}
              disabled={busy}
            >
              Try a private demo <ArrowRight size={17} />
            </button>
          )}
          <div className="demo-note">
            <Sparkles size={18} />
            <div>
              <strong>
                {capabilities.demo
                  ? "Your own two-hour workspace"
                  : "Exploring the local demo?"}
              </strong>
              <p>
                {capabilities.demo
                  ? "Try the complete review flow with fictional samples. Each visitor has a separate workspace. No uploads or live AI calls in the public demo."
                  : "Use the password supplied during setup. Rules-based extraction works offline; live AI is available only when configured."}
              </p>
            </div>
          </div>
        </section>
      </div>
    );
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Brand />
        <div className="workspace-name">
          <span>M</span>
          <div>
            {user.workspace}
            <small>Team workspace</small>
          </div>
        </div>
        <div className="nav-label">WORKSPACE</div>
        <button
          className="nav-item"
          onClick={() => {
            selectionRequest.current++;
            setSelected(null);
            setLoadingDocument(false);
            setFilter("all");
            setQuery("");
          }}
        >
          <LayoutDashboard size={18} /> Overview
        </button>
        <button
          className="nav-item active"
          onClick={() => {
            setFilter("all");
            setQuery("");
          }}
        >
          <Files size={18} /> Agreements{" "}
          <span className="count">{docs.length}</span>
        </button>
        <button
          className="nav-item"
          onClick={() => {
            setFilter("approved");
            setSelected(null);
          }}
        >
          <ShieldCheck size={18} /> Approved{" "}
          <span className="count">{approved}</span>
        </button>
        <div className="sidebar-bottom">
          <div className="trust-card">
            <ShieldCheck size={20} />
            <strong>Your judgment comes first.</strong>
            <p>Extracted fields are drafts until a reviewer signs off.</p>
          </div>
          <div className="account">
            <span className="avatar">
              {user.name
                .split(" ")
                .map((n) => n[0])
                .join("")}
            </span>
            <div>
              <strong>{user.name}</strong>
              <small>
                {user.role === "reviewer"
                  ? "Contract reviewer"
                  : "Read-only viewer"}
              </small>
            </div>
            <button
              className="icon-button"
              aria-label="Sign out"
              onClick={logout}
            >
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>
      <main>
        <header className="topbar">
          <div>
            Workspace <ChevronRight size={13} />
            <strong>Agreements</strong>
          </div>
          <span className="mode">
            <span />{" "}
            {user.demo
              ? "Private demo · Fictional samples"
              : "Evidence-led contract review"}
          </span>
          <button
            className="icon-button mobile-signout"
            aria-label="Sign out on mobile"
            onClick={logout}
          >
            <LogOut size={16} />
          </button>
        </header>
        <div className="page">
          <div className="page-heading">
            <div className="eyebrow">CONTRACT OPERATIONS</div>
            <div className="heading-row">
              <div>
                <h1>Clarity, before you commit.</h1>
                <p>Review the facts. Keep the evidence. Make the call.</p>
              </div>
              {canReview && (
                <button className="primary" onClick={() => setModal(true)}>
                  <Plus size={17} /> New agreement
                </button>
              )}
            </div>
          </div>
          <div className="stats">
            <Stat
              icon={<Files size={19} />}
              label="Total agreements"
              value={docs.length}
              note="In your workspace"
            />
            <Stat
              icon={<Clock3 size={19} />}
              label="Awaiting review"
              value={docs.length - approved}
              note="Your next decisions"
            />
            <Stat
              icon={<ShieldCheck size={19} />}
              label="Approved"
              value={approved}
              note="Reviewed and export-ready"
            />
          </div>
          {error && (
            <div role="alert" className="error error-bar">
              {error}
              {selected && (
                <button onClick={() => openDocument(selected.id)}>
                  Reload document
                </button>
              )}
              <button
                className="icon-button"
                aria-label="Dismiss error"
                onClick={() => setError("")}
              >
                <X size={16} />
              </button>
            </div>
          )}
          <section className="workbench">
            <div className="list-panel">
              <div className="list-heading">
                <h2>
                  Agreements <span>{docs.length}</span>
                </h2>
                <button
                  className="icon-button"
                  aria-label="Refresh agreements"
                  onClick={() => run(refresh)}
                >
                  <History size={16} />
                </button>
              </div>
              <label className="search">
                <Search size={16} />
                <input
                  aria-label="Search agreements"
                  placeholder="Search agreements…"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                />
              </label>
              <div className="filters">
                {[
                  ["all", "All"],
                  ["draft", "To review"],
                  ["approved", "Approved"],
                ].map(([v, l]) => (
                  <button
                    key={v}
                    className={filter === v ? "selected" : ""}
                    onClick={() => setFilter(v)}
                  >
                    {l}
                  </button>
                ))}
              </div>
              <div className="document-list">
                {visible.map((doc) => (
                  <button
                    key={doc.id}
                    className={`doc-row ${selected?.id === doc.id ? "selected" : ""}`}
                    onClick={() => openDocument(doc.id)}
                  >
                    <div className="doc-row-top">
                      <span className="file-icon">
                        <FileText size={19} />
                      </span>
                      <span className={`badge ${doc.status}`}>
                        {doc.status === "approved" ? "Approved" : "To review"}
                      </span>
                    </div>
                    <strong>{doc.title}</strong>
                    <small>
                      {doc.filename} · {date(doc.created_at)}
                    </small>
                    <div className="doc-progress">
                      <span>
                        {doc.reviewed_count}/{doc.field_count} fields reviewed
                      </span>
                      <ArrowUpRight size={14} />
                    </div>
                    <div className="progress-track">
                      <span
                        style={{
                          width: `${(doc.reviewed_count / doc.field_count) * 100}%`,
                        }}
                      />
                    </div>
                  </button>
                ))}
                {!visible.length && (
                  <div className="empty-list">
                    {docs.length
                      ? "No agreements match your search."
                      : "Your first agreement starts here."}
                  </div>
                )}
              </div>
              <div className="list-footer">
                <ShieldCheck size={13} /> Workspace-scoped access
              </div>
            </div>
            {loadingDocument ? (
              <div className="empty-detail">Loading agreement…</div>
            ) : selected ? (
              <div className="detail-panel">
                <div className="detail-header">
                  <div className="detail-kicker">
                    <span className={`badge ${selected.status}`}>
                      {selected.status === "approved"
                        ? "Approved"
                        : "Review in progress"}
                    </span>
                    <span>Version {selected.revision + 1}</span>
                  </div>
                  <h2>{selected.title}</h2>
                  {canReview &&
                    !user.demo &&
                    capabilities.live_ai &&
                    selected.status === "draft" &&
                    selected.reviewed_count === 0 && (
                      <div className="ai-controls">
                        <label>
                          <input
                            type="checkbox"
                            checked={aiConsent}
                            disabled={busy}
                            onChange={(e) => setAiConsent(e.target.checked)}
                          />{" "}
                          Send this document’s text to OpenAI for extraction.
                        </label>
                        <button
                          className="secondary"
                          disabled={busy || !aiConsent}
                          onClick={extract}
                        >
                          {extracting
                            ? "Checking source citations…"
                            : "Extract with AI"}
                        </button>
                        <small>
                          Up to 70 seconds. Three attempts per document. Review
                          every suggestion before approval.
                        </small>
                      </div>
                    )}
                  <div className="detail-meta">
                    <FileText size={14} />
                    {selected.page_count}{" "}
                    {selected.page_count === 1 ? "page" : "pages"}
                    <span>•</span>Added {date(selected.created_at)}
                    <button
                      className={history ? "text-button chosen" : "text-button"}
                      onClick={() => setHistory(!history)}
                    >
                      <History size={14} /> Activity
                    </button>
                  </div>
                </div>
                {history ? (
                  <div className="history">
                    <h3>Decision history</h3>
                    <p>
                      Every correction and approval stays connected to its
                      reviewer.
                    </p>
                    {selected.events?.map((event) => (
                      <article key={event.id}>
                        <span className="timeline-dot" />
                        <strong>
                          {event.action === "uploaded"
                            ? "Agreement uploaded"
                            : event.action === "approved"
                              ? "Agreement approved"
                              : event.action === "ai_extracted"
                                ? "AI suggestions extracted · review required"
                                : `${event.details.field} reviewed`}
                        </strong>
                        <small>
                          {event.actor} ·{" "}
                          {new Date(event.created_at).toLocaleString()}
                        </small>
                        {event.details.after && (
                          <p>
                            {event.details.after.review_state === "omitted"
                              ? "Omitted"
                              : event.details.after.value}
                            {event.details.after.note &&
                              ` — ${event.details.after.note}`}
                          </p>
                        )}
                      </article>
                    ))}
                  </div>
                ) : (
                  <>
                    <div className="review-columns">
                      <section className="source-panel">
                        <div className="panel-heading">
                          <h3>Source document</h3>
                          <span>READ ONLY</span>
                        </div>
                        <div className="paper-scroll">
                          {selected.pages?.map((page) => (
                            <div className="paper" key={page.number}>
                              <div className="paper-top">
                                <span>ORIGINAL TEXT</span>
                                <span>PAGE {page.number}</span>
                              </div>
                              {page.text.split("\n").map((line, i) => {
                                const field = selected.fields?.find(
                                  (f) =>
                                    f.evidence === line.trim() &&
                                    f.page === page.number,
                                );
                                return (
                                  <div
                                    key={i}
                                    data-source-field={field?.id}
                                    className={
                                      field
                                        ? activeField === field.id
                                          ? "source-line highlight focused"
                                          : "source-line highlight"
                                        : "source-line"
                                    }
                                  >
                                    {line || "\u00A0"}
                                  </div>
                                );
                              })}
                            </div>
                          ))}
                        </div>
                        <div className="source-foot">
                          Original text preserved · SHA-256 fingerprint stored
                        </div>
                      </section>
                      <section className="fields-panel">
                        <div className="panel-heading">
                          <h3>Review fields</h3>
                          <span>
                            {selected.reviewed_count} / {selected.field_count}
                          </span>
                        </div>
                        <div className="extraction-note">
                          <Sparkles size={16} />
                          <span>
                            {selected.extraction_mode === "live_ai"
                              ? `AI draft · ${selected.extraction_metadata.model}. Citations checked; meaning still needs your review.`
                              : "Rules-based extraction. You decide what to keep."}
                          </span>
                        </div>
                        <div className="fields-scroll">
                          {selected.fields?.map((field) => (
                            <FieldCard
                              key={`${selected.id}-${field.id}-${selected.revision}`}
                              field={field}
                              disabled={
                                busy ||
                                !canReview ||
                                selected.status === "approved"
                              }
                              onFocus={() => setActiveField(field.id)}
                              onReview={review}
                            />
                          ))}
                        </div>
                      </section>
                    </div>
                    <footer className="review-footer">
                      <div>
                        <CheckCheck size={19} />
                        <span>
                          <strong>
                            {selected.status === "approved"
                              ? "Review complete"
                              : `${selected.field_count - selected.reviewed_count} fields left to review`}
                          </strong>
                          <small>
                            {selected.status === "approved"
                              ? "Locked with a recorded approval."
                              : "Accept or explicitly omit every field."}
                          </small>
                        </span>
                      </div>
                      {selected.status === "approved" ? (
                        <button
                          className="primary"
                          onClick={download}
                          disabled={busy}
                        >
                          <ArrowDownToLine size={16} /> Export CSV
                        </button>
                      ) : (
                        canReview && (
                          <button
                            className="primary"
                            disabled={
                              busy ||
                              selected.reviewed_count !== selected.field_count
                            }
                            onClick={approve}
                          >
                            <ShieldCheck size={16} /> Approve agreement
                          </button>
                        )
                      )}
                    </footer>
                  </>
                )}
              </div>
            ) : (
              <div className="empty-detail">
                <div className="empty-icon">
                  <Files size={30} />
                </div>
                <h2>A clear view of every agreement.</h2>
                <p>
                  Select an agreement to review its facts alongside the source,
                  or start with our fictional sample.
                </p>
                {canReview && (
                  <button className="primary" onClick={sample} disabled={busy}>
                    <Sparkles size={17} /> Explore a sample agreement
                  </button>
                )}
                <div className="empty-steps">
                  <span>01 / Read</span>
                  <span>02 / Review</span>
                  <span>03 / Approve</span>
                </div>
              </div>
            )}
          </section>
          <div className="page-footer">
            <span>CLAUSEDESK</span>
            <span>Built for considered decisions.</span>
            <span>Portfolio demo · Synthetic samples only</span>
          </div>
        </div>
      </main>
      {modal && (
        <div
          className="modal-overlay"
          onClick={(e) => {
            if (e.target === e.currentTarget && !busy) setModal(false);
          }}
        >
          <section
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="upload-title"
          >
            <button
              className="icon-button close-modal"
              aria-label="Close upload"
              onClick={() => setModal(false)}
              disabled={busy}
            >
              <X size={20} />
            </button>
            <div className="eyebrow">NEW AGREEMENT</div>
            <h2 id="upload-title">Bring the source into focus.</h2>
            <p>
              {user.demo
                ? "This isolated demo uses fictional samples only. Your workspace expires after two hours."
                : "Upload a text PDF or UTF-8 .txt file. Maximum 2 MB and 30 pages. Scanned PDFs are not supported yet."}
            </p>
            {!user.demo && (
              <form onSubmit={upload}>
                <label>
                  Agreement name
                  <input
                    autoFocus
                    required
                    maxLength={160}
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g. Northstar services agreement"
                  />
                </label>
                <label className="upload-zone">
                  <Upload size={25} />
                  <strong>{file?.name || "Choose your document"}</strong>
                  <span>PDF or TXT · up to 2 MB</span>
                  <input
                    required
                    aria-label="Document file"
                    type="file"
                    accept=".pdf,.txt"
                    onChange={(e) => setFile(e.target.files?.[0] || null)}
                  />
                </label>
                {error && (
                  <div role="alert" className="error">
                    {error}
                  </div>
                )}
                <button className="primary" disabled={busy || !file}>
                  {busy ? "Reading document…" : "Upload and extract fields"}
                  <ArrowRight size={16} />
                </button>
              </form>
            )}
            {user.demo && error && (
              <div role="alert" className="error">
                {error}
              </div>
            )}
            <div className="modal-divider">OR EXPLORE FIRST</div>
            <button className="secondary full" onClick={sample} disabled={busy}>
              <Sparkles size={16} /> Load fictional sample
            </button>
          </section>
        </div>
      )}
    </div>
  );
}
function Stat({
  icon,
  label,
  value,
  note,
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
  note: string;
}) {
  return (
    <div className="stat">
      <div className="stat-label">
        {icon}
        {label}
      </div>
      <div className="stat-bottom">
        <strong>{String(value).padStart(2, "0")}</strong>
        <span>{note}</span>
      </div>
    </div>
  );
}
function FieldCard({
  field,
  disabled,
  onFocus,
  onReview,
}: {
  field: Field;
  disabled: boolean;
  onFocus: () => void;
  onReview: (
    field: Field,
    value: string,
    note: string,
    state: string,
  ) => Promise<void>;
}) {
  const [value, setValue] = useState(field.value || "");
  const [note, setNote] = useState(field.note || "");
  const [editing, setEditing] = useState(false);
  return (
    <article
      className={`field-card ${field.review_state !== "pending" ? "reviewed" : ""}`}
      onFocus={onFocus}
    >
      <div className="field-top">
        <label htmlFor={`field-${field.id}`}>{field.label}</label>
        {field.review_state === "pending" ? (
          <span className={field.value ? "field-source" : "missing"}>
            {field.value ? `Page ${field.page}` : "Not found"}
          </span>
        ) : (
          <span className="field-done">
            <Check size={12} />
            {field.review_state === "accepted" ? "Accepted" : "Omitted"}
          </span>
        )}
      </div>
      <input
        id={`field-${field.id}`}
        value={value}
        placeholder="No explicit value in source"
        disabled={disabled}
        onChange={(e) => {
          setValue(e.target.value);
          setEditing(true);
        }}
      />
      {field.evidence && (
        <button
          className="evidence-link"
          onClick={onFocus}
          title={field.evidence}
        >
          View source evidence <ArrowUpRight size={12} />
        </button>
      )}
      {!field.evidence && (
        <p className="missing-note">
          {field.uncertainty ||
            "No unambiguous value found. Add a supported correction or record why it is omitted."}
        </p>
      )}
      {(editing || !field.value || field.note) && (
        <textarea
          aria-label={`${field.label} review note`}
          placeholder="Explain your correction or omission…"
          value={note}
          disabled={disabled}
          onChange={(e) => setNote(e.target.value)}
        />
      )}
      <div className="field-actions">
        <button
          disabled={disabled || !value.trim()}
          onClick={() => onReview(field, value, note, "accepted")}
        >
          <Check size={13} /> Accept
        </button>
        <button
          disabled={disabled}
          onClick={() => {
            if (!note.trim()) {
              setEditing(true);
              return;
            }
            onReview(field, value, note, "omitted");
          }}
        >
          Omit
        </button>
        {!editing && field.value && (
          <button disabled={disabled} onClick={() => setEditing(true)}>
            Add note
          </button>
        )}
      </div>
    </article>
  );
}
createRoot(document.getElementById("root")!).render(<App />);
