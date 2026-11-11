// OpenCode (v2 ServerPlugin) -> Dynamic Island bridge.
//
// Installed by `dynamic-island-agent-setup opencode` as a symlink in
// ~/.config/opencode/plugins/. Reports session, tool, model switcher, and
// permission events over the island's unix socket without blocking OpenCode.

import fs from "node:fs"
import net from "node:net"
import os from "node:os"
import path from "node:path"

const HOME = os.homedir()
const RUNTIME = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid?.() ?? 1000}`
const SOCK = path.join(RUNTIME, "dynamic-island", "agents.sock")
const OPENCODE_DB = path.join(HOME, ".local", "share", "opencode", "opencode.db")

const SUBSCRIBE_TYPES = [
  "session.created",
  "session.deleted",
  "session.moved",
  "session.model.selected",
  "session.execution.started",
  "session.execution.succeeded",
  "session.execution.failed",
  "session.execution.interrupted",
  "session.step.started",
  "session.status",
  "session.idle",
  "session.compaction.started",
  "session.compaction.ended",
  "session.compaction.failed",
  "permission.asked",
  "permission.replied",
  "form.created",
  "form.replied",
  "form.cancelled",
]

function normDir(p) {
  return String(p || "").replace(/[\/\s]+$/, "")
}

function displayProject(cwd) {
  const cleaned = normDir(cwd)
  return path.basename(cleaned) || cleaned || cwd || "opencode"
}

let lastTs = 0
function nextTs() {
  const us = Math.round(performance.timeOrigin * 1000 + performance.now() * 1000)
  lastTs = Math.max(us, lastTs + 1)
  return lastTs
}

function send(msg, { waitForReply = false } = {}) {
  return new Promise((resolve) => {
    let buf = ""
    let settled = false
    const finish = (value) => {
      if (settled) return
      settled = true
      try { socket.destroy() } catch {}
      resolve(value)
    }
    const socket = net.createConnection(SOCK)
    socket.setEncoding("utf8")
    socket.on("error", () => finish(null))
    socket.on("close", () => finish(null))
    socket.on("connect", () => {
      try { socket.write(JSON.stringify(msg) + "\n") } catch { finish(null) }
    })
    socket.on("data", (chunk) => {
      buf += chunk
      const nl = buf.indexOf("\n")
      if (nl === -1) return
      const line = buf.slice(0, nl)
      if (!waitForReply) return finish(line)
      try { finish(JSON.parse(line)) } catch { finish(null) }
    })
    if (!waitForReply) setTimeout(() => finish(null), 1000)
  })
}

function readProcBasic(pid) {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8")
    const end = stat.lastIndexOf(")")
    if (end === -1) return null
    const comm = stat.slice(stat.indexOf("(") + 1, end)
    const ppid = parseInt(stat.slice(end + 2).split(/\s+/)[1], 10) || 0
    return { pid, comm, ppid }
  } catch {
    return null
  }
}

function pidChain(pid, limit = 16) {
  const out = []
  let cur = pid
  while (cur > 1 && out.length < limit) {
    out.push(cur)
    const info = readProcBasic(cur)
    if (!info || info.ppid <= 1) break
    cur = info.ppid
  }
  return out
}

function selfTty() {
  try {
    return fs.readlinkSync("/proc/self/fd/0").startsWith("/dev/pts/")
  } catch {
    return false
  }
}

const OPENCODE_NON_TUI_SUBCOMMANDS = new Set([
  "upgrade", "update", "uninstall", "acp", "api", "debug", "auth",
  "mcp", "plugin", "models", "stats", "session", "service", "reload",
  "pair", "serve",
])
const OPENCODE_EXIT_FLAGS = new Set(["-h", "--help", "-v", "--version", "--wizard", "--service"])
const OPENCODE_VALUE_FLAGS = new Set([
  "--server", "-s", "--session", "--prompt", "--log-level", "--completions",
  "-m", "--model", "--agent", "--title", "--format", "-n", "--file", "-f",
  "--dir", "--port", "--hostname", "--command", "--variant",
])

function isInteractiveOpencodeArgv(argv) {
  const pos = []
  let skipNext = false
  for (const a of argv.slice(1)) {
    if (!a) continue
    if (skipNext) { skipNext = false; continue }
    if (OPENCODE_EXIT_FLAGS.has(a) || a === "--completions" || a.startsWith("--completions=")) return false
    if (OPENCODE_VALUE_FLAGS.has(a)) { skipNext = true; continue }
    if (a.startsWith("-")) continue
    pos.push(a)
  }
  if (pos.length && !pos[0].includes("/") && !pos[0].startsWith(".") && OPENCODE_NON_TUI_SUBCOMMANDS.has(pos[0])) {
    return false
  }
  return true
}

const procCache = { at: 0, entries: [] }
function listInteractiveOpencodeTuis() {
  const now = Date.now()
  if (now - procCache.at < 1500) return procCache.entries
  const out = []
  try {
    for (const name of fs.readdirSync("/proc")) {
      if (!/^\d+$/.test(name)) continue
      const pid = Number(name)
      const basic = readProcBasic(pid)
      if (!basic) continue
      let cmd = ""
      try { cmd = fs.readFileSync(`/proc/${pid}/cmdline`, "utf8") } catch { continue }
      const argv = cmd.split("\0")
      const exe = argv[0] ? path.basename(argv[0]) : basic.comm
      if (exe !== "opencode" && exe !== "opencode.exe" && basic.comm !== "opencode" && basic.comm !== "opencode.exe") {
        continue
      }
      if (!isInteractiveOpencodeArgv(argv)) continue
      let tty = ""
      try { tty = fs.readlinkSync(`/proc/${pid}/fd/0`) } catch { continue }
      if (!tty.startsWith("/dev/pts/")) continue
      let cwd = ""
      try { cwd = fs.readlinkSync(`/proc/${pid}/cwd`) } catch {}
      out.push({ pid, cwd })
    }
  } catch {}
  procCache.at = now
  procCache.entries = out
  return out
}

const HAS_SELF_TTY = selfTty()

function resolveProcess(cwd) {
  if (HAS_SELF_TTY) {
    return { agentPid: process.pid, pids: pidChain(process.pid) }
  }
  const tuis = listInteractiveOpencodeTuis()
  if (!tuis.length) return { agentPid: 0, pids: [] }
  const target = normDir(cwd)
  const exact = tuis.find((t) => target && normDir(t.cwd) === target)
  if (exact) return { agentPid: exact.pid, pids: pidChain(exact.pid) }
  // Users often start `opencode` in $HOME and open a project workspace inside TUI.
  const homeMatch = tuis.find((t) => normDir(t.cwd) === normDir(HOME) || (target && target.startsWith(normDir(t.cwd) + "/")))
  const pick = homeMatch || (tuis.length === 1 ? tuis[0] : null)
  return pick ? { agentPid: pick.pid, pids: pidChain(pick.pid) } : { agentPid: 0, pids: [] }
}

function describe(tool, args = {}) {
  const a = args && typeof args === "object" ? args : {}
  const t = String(tool || "")
  const fp = a.filePath || a.file_path || a.path || ""
  if (t === "bash" || t === "shell") return [String(a.description || "Command"), String(a.command || "")]
  if (t === "edit") {
    const oldS = String(a.oldString ?? a.old_string ?? "").split("\n").slice(0, 6).join("\n- ")
    const newS = String(a.newString ?? a.new_string ?? "").split("\n").slice(0, 6).join("\n+ ")
    return [String(fp), oldS || newS ? `- ${oldS}\n+ ${newS}` : ""]
  }
  if (t === "write") return [String(fp), String(a.content || "").split("\n").slice(0, 8).join("\n")]
  if (t === "read") return [String(fp), ""]
  if (t === "glob" || t === "grep") return [String(a.pattern || a.query || ""), String(a.path || "")]
  if (t === "webfetch" || t === "websearch") return [String(a.url || a.query || ""), ""]
  const first = Object.values(a).find((v) => typeof v === "string" && v.trim()) || ""
  return [String(first).slice(0, 160), JSON.stringify(a).slice(0, 400)]
}

function errorText(err) {
  if (!err) return ""
  if (typeof err === "string") return err
  return String(err.message || err.error?.message || err.type || "")
}

const metaBySession = new Map()
const busy = new Set()
const starting = new Set()

export default {
  id: "dynamic-island",
  setup(ctx) {
    const ac = new AbortController()
    const cleanups = []
    const defaultDir = ctx.location?.directory || process.cwd()

    function transcriptFor(sessionID) {
      return sessionID ? `${OPENCODE_DB}#${sessionID}` : ""
    }

    function updateMeta(sessionID, patch) {
      if (!sessionID) return {}
      const prev = metaBySession.get(sessionID) || { cwd: defaultDir, parentID: "", model: null }
      const next = {
        cwd: patch.cwd || prev.cwd || defaultDir,
        parentID: patch.parentID !== undefined ? patch.parentID : prev.parentID,
        model: patch.model || prev.model,
        fetched: patch.fetched !== undefined ? patch.fetched : prev.fetched,
      }
      metaBySession.set(sessionID, next)
      return next
    }

    async function ensureMeta(sessionID) {
      const existing = metaBySession.get(sessionID)
      if (existing?.fetched || !ctx.session?.get) return existing || { cwd: defaultDir, parentID: "", model: null }
      try {
        const raw = await ctx.session.get({ sessionID })
        const info = raw?.id ? raw : raw?.data
        if (info) {
          return updateMeta(sessionID, {
            cwd: info.directory || info.location?.directory,
            parentID: info.parentID || "",
            model: info.model || undefined,
            fetched: true,
          })
        }
      } catch {}
      return updateMeta(sessionID, { fetched: true })
    }

    function base(sessionID, evLocation) {
      const meta = (sessionID && metaBySession.get(sessionID)) || {}
      const cwd = evLocation?.directory || meta.cwd || defaultDir
      const proc = resolveProcess(cwd)
      const modelObj = meta.model || null
      return {
        agent: "opencode",
        cwd,
        project: displayProject(cwd),
        pids: proc.pids,
        agentPid: proc.agentPid,
        transcript: transcriptFor(sessionID),
        model: modelObj?.id || "",
        provider: modelObj?.providerID || "",
        ts: nextTs(),
      }
    }

    async function replyPermission(sessionID, requestID, behavior) {
      const decision = behavior === "always" ? "always" : behavior === "deny" ? "reject" : "once"
      if (ctx.permission?.reply) {
        return ctx.permission.reply({ sessionID, requestID, decision })
      }
    }

    async function onPermissionAsked(p, evLocation) {
      const sessionID = p.sessionID
      const requestID = p.id
      if (!sessionID || !requestID) return
      await ensureMeta(sessionID)
      const [fallbackTitle, fallbackDetail] = describe(p.action || "", p.metadata || {})
      const resText = Array.isArray(p.resources) ? p.resources.join(", ") : ""
      const title = p.message || resText || fallbackTitle
      const detail = fallbackDetail || (p.message && resText ? resText : "")
      const reply = await send({
        ...base(sessionID, evLocation),
        event: "PermissionRequest",
        session: sessionID,
        request: `opencode-${requestID}`,
        tool: p.action || "permission",
        title,
        detail,
        canAlways: true,
      }, { waitForReply: true })
      if (!reply || !["allow", "always", "deny"].includes(reply.behavior)) return
      try { await replyPermission(sessionID, requestID, reply.behavior) } catch {}
    }

    if (ctx.tool?.hook) {
      const before = ctx.tool.hook("execute.before", (e) => {
        try {
          if (!e?.sessionID) return
          const meta = metaBySession.get(e.sessionID)
          if (meta?.parentID) return
          const [title, detail] = describe(e.tool, e.input || {})
          void send({
            ...base(e.sessionID),
            event: "PreToolUse",
            session: e.sessionID,
            tool: e.tool || "tool",
            title,
            detail,
          })
        } catch {}
      })
      const after = ctx.tool.hook("execute.after", (e) => {
        try {
          if (!e?.sessionID) return
          const meta = metaBySession.get(e.sessionID)
          if (meta?.parentID) return
          void send({
            ...base(e.sessionID),
            event: e.status === "error" ? "PostToolUseFailure" : "PostToolUse",
            session: e.sessionID,
            tool: e.tool || "tool",
          })
        } catch {}
      })
      cleanups.push(() => { try { before?.dispose?.() } catch {} })
      cleanups.push(() => { try { after?.dispose?.() } catch {} })
    }

    async function handleEvent(ev) {
      if (!ev || !ev.type) return
      const evDir = ev.location?.directory
      if (evDir && ctx.location?.directory && normDir(evDir) !== normDir(ctx.location.directory)) return
      const d = ev.data || {}
      const sid = d.sessionID || d.form?.sessionID || ""

      switch (ev.type) {
        case "session.created": {
          const meta = updateMeta(sid, {
            cwd: d.location?.directory || evDir,
            parentID: d.parentID || "",
            model: d.model || null,
            fetched: true,
          })
          if (!meta.parentID && sid) {
            void send({ ...base(sid, ev.location), event: "SessionStart", session: sid })
          }
          break
        }

        case "session.deleted":
          busy.delete(sid)
          metaBySession.delete(sid)
          if (sid) void send({ ...base(sid, ev.location), event: "SessionEnd", session: sid })
          break

        case "session.moved": {
          const meta = updateMeta(sid, { cwd: d.location?.directory || evDir })
          if (!meta.parentID && sid) {
            void send({ ...base(sid, ev.location), event: "SessionUpdate", session: sid })
          }
          break
        }

        case "session.model.selected": {
          const meta = updateMeta(sid, { model: d.model || null })
          if (!meta.parentID && sid) {
            void send({ ...base(sid, ev.location), event: "ModelChanged", session: sid })
          }
          break
        }

        case "session.step.started": {
          if (!sid) break
          const prevModel = metaBySession.get(sid)?.model
          if (d.model) updateMeta(sid, { model: d.model })
          if (!busy.has(sid) && !starting.has(sid)) {
            starting.add(sid)
            try {
              const meta = await ensureMeta(sid)
              if (d.model) updateMeta(sid, { model: d.model })
              if (!meta.parentID && !busy.has(sid)) {
                busy.add(sid)
                void send({ ...base(sid, ev.location), event: "UserPromptSubmit", session: sid })
              }
            } finally {
              starting.delete(sid)
            }
          } else {
            const meta = metaBySession.get(sid) || {}
            if (!meta.parentID && d.model && (d.model.id !== prevModel?.id || d.model.providerID !== prevModel?.providerID)) {
              void send({ ...base(sid, ev.location), event: "ModelChanged", session: sid })
            }
          }
          break
        }

        case "session.execution.started": {
          if (!sid || busy.has(sid) || starting.has(sid)) break
          starting.add(sid)
          try {
            const meta = await ensureMeta(sid)
            if (!meta.parentID && !busy.has(sid)) {
              busy.add(sid)
              void send({ ...base(sid, ev.location), event: "UserPromptSubmit", session: sid })
            }
          } finally {
            starting.delete(sid)
          }
          break
        }

        case "session.execution.succeeded": {
          if (!sid || !busy.delete(sid)) break
          const meta = await ensureMeta(sid)
          if (!meta.parentID) {
            void send({ ...base(sid, ev.location), event: "Stop", session: sid })
          }
          break
        }

        case "session.execution.failed": {
          if (!sid) break
          busy.delete(sid)
          const meta = await ensureMeta(sid)
          if (!meta.parentID) {
            void send({ ...base(sid, ev.location), event: "StopFailure", session: sid, error: errorText(d.error) })
          }
          break
        }

        case "session.execution.interrupted": {
          if (!sid) break
          busy.delete(sid)
          const meta = await ensureMeta(sid)
          if (!meta.parentID) {
            void send({ ...base(sid, ev.location), event: "Interrupt", session: sid })
          }
          break
        }

        case "session.status": {
          if (!sid) break
          if (d.status?.type === "busy" && !busy.has(sid) && !starting.has(sid)) {
            starting.add(sid)
            try {
              const meta = await ensureMeta(sid)
              if (!meta.parentID && !busy.has(sid)) {
                busy.add(sid)
                void send({ ...base(sid, ev.location), event: "UserPromptSubmit", session: sid })
              }
            } finally {
              starting.delete(sid)
            }
          } else if (d.status?.type === "idle" && busy.delete(sid)) {
            const meta = await ensureMeta(sid)
            if (!meta.parentID) {
              void send({ ...base(sid, ev.location), event: "Stop", session: sid })
            }
          }
          break
        }

        case "session.idle": {
          if (!sid || !busy.delete(sid)) break
          const meta = await ensureMeta(sid)
          if (!meta.parentID) {
            void send({ ...base(sid, ev.location), event: "Stop", session: sid })
          }
          break
        }

        case "session.compaction.started": {
          const meta = await ensureMeta(sid)
          if (!meta.parentID && sid) {
            void send({ ...base(sid, ev.location), event: "PreCompact", session: sid, trigger: d.reason || "auto" })
          }
          break
        }

        case "session.compaction.ended":
        case "session.compaction.failed": {
          const meta = await ensureMeta(sid)
          if (!meta.parentID && sid) {
            void send({ ...base(sid, ev.location), event: "PostCompact", session: sid, trigger: d.reason || "auto" })
          }
          break
        }

        case "permission.asked":
          void onPermissionAsked(d, ev.location)
          break

        case "permission.replied":
          if (sid) {
            void send({
              ...base(sid, ev.location),
              event: "PermissionResolved",
              session: sid,
              request: `opencode-${d.requestID || d.id || ""}`,
            })
          }
          break

        case "form.created":
          if (d.form?.sessionID) {
            await ensureMeta(d.form.sessionID)
            void send({
              ...base(d.form.sessionID, ev.location),
              event: "Question",
              session: d.form.sessionID,
              message: String(d.form.title || d.form.metadata?.kind || ""),
            })
          }
          break

        case "form.replied":
        case "form.cancelled":
          if (sid) {
            await ensureMeta(sid)
            void send({
              ...base(sid, ev.location),
              event: busy.has(sid) ? "PostToolUse" : "SessionStart",
              session: sid,
            })
          }
          break
      }
    }

    if (ctx.event?.subscribe) {
      ;(async () => {
        try {
          const stream = ctx.event.subscribe({ types: SUBSCRIBE_TYPES, signal: ac.signal })
          for await (const ev of stream) {
            if (ac.signal.aborted) break
            try { await handleEvent(ev) } catch {}
          }
        } catch {}
      })()
    }

    return () => {
      ac.abort()
      for (const fn of cleanups) fn()
    }
  },
}
