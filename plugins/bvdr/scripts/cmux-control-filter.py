#!/usr/bin/env python3
"""Tail cmux workstream.jsonl + poll claude-hook-sessions.json.

Surfaces actionable cross-session events to ~/.config/cmux-control/events.log.
A separate state.json lists which sessions the user is monitoring; events from
unmonitored sessions are recorded but tagged so the control session can ignore
them by default.

Event kinds:
- DECISION_NEEDED: agent asking AskUserQuestion or ExitPlanMode
- PERM_PENDING:    other tool waiting on Feed approval
- IDLE:            Claude posted "waiting for your input" (work paused, awaits user)
- BUSY:            Idle session resumed (transition: Waiting -> not-Waiting)
- DONE:            sessionEnd (process exited)
- SESSION_START:   new agent session
"""
import json, time, os, threading

HOME = os.path.expanduser("~")
WORKSTREAM = os.path.join(HOME, ".cmuxterm", "workstream.jsonl")
SESSIONS = os.path.join(HOME, ".cmuxterm", "claude-hook-sessions.json")
CMUX_SESSION = os.path.join(HOME, "Library", "Application Support", "cmux", "session-com.cmuxterm.app.json")
OUT_PATH = os.path.join(HOME, ".config", "cmux-control", "events.log")

ACTIONABLE_TOOLS = {"AskUserQuestion", "ExitPlanMode"}
MAP_REFRESH_SEC = 30
IDLE_POLL_SEC = 5
IDLE_DEBOUNCE_SEC = 60  # only emit IDLE after this much quiet time since last activity (covers Skill loading pauses)

_session_to_ws = {}
_last_refresh = 0
# sessionId -> bool: whether we've already emitted IDLE for the current quiet stretch
_idle_emitted = {}
# sessionId -> float: monotonic time of last workstream activity (toolUse/userPrompt)
_last_activity = {}

def refresh_map():
    global _session_to_ws, _last_refresh
    try:
        d = json.load(open(CMUX_SESSION))
    except Exception:
        return
    m = {}
    for w in d.get("windows", []):
        for ws in w.get("tabManager", {}).get("workspaces", []):
            name = ws.get("customTitle") or ws.get("processTitle") or "(unnamed)"
            for p in ws.get("panels", []):
                sid = (p.get("terminal") or {}).get("agent", {}).get("sessionId")
                if sid:
                    m[sid] = name
    _session_to_ws = m
    _last_refresh = time.time()

def ws_name_for_session(sid):
    if time.time() - _last_refresh > MAP_REFRESH_SEC:
        refresh_map()
    return _session_to_ws.get(sid, f"unknown({sid[:8]})")

def ws_name(workstream_id):
    if workstream_id.startswith("claude-"):
        return ws_name_for_session(workstream_id[len("claude-"):])
    return workstream_id

_emit_lock = threading.Lock()
def emit(line):
    with _emit_lock, open(OUT_PATH, "a") as f:
        f.write(line + "\n")

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def handle_workstream(d):
    src = d.get("source")
    if src not in ("claude", "codex", "opencode"):
        return
    wsid = d.get("workstreamId", "")
    name = ws_name(wsid)
    kind = d.get("kind")
    # Track activity timestamp for idle-debouncing and emit BUSY when a session
    # we previously flagged as idle resumes work.
    if wsid.startswith("claude-") and kind in ("toolUse", "userPrompt"):
        sid = wsid[len("claude-"):]
        _last_activity[sid] = time.time()
        if _idle_emitted.get(sid):
            _idle_emitted[sid] = False
            emit(f"[{d.get('createdAt','')}] [{name}] BUSY (resumed)")
    ts = d.get("createdAt", "")
    pl = d.get("payload", {})
    status = d.get("status", {})
    is_pending = "pending" in status

    if kind == "permissionRequest":
        pr = pl.get("permissionRequest", {})
        tool = pr.get("toolName", "?")
        try:
            inp = json.loads(pr.get("toolInputJSON", "{}"))
        except Exception:
            inp = {}
        if tool in ACTIONABLE_TOOLS:
            emit(f"[{ts}] [{name}] DECISION_NEEDED kind={tool} input={json.dumps(inp)[:600]}")
        elif is_pending:
            desc = inp.get("description") or inp.get("command") or ""
            emit(f"[{ts}] [{name}] PERM_PENDING tool={tool} desc={str(desc)[:120]}")
    elif kind == "sessionEnd":
        emit(f"[{ts}] [{name}] DONE (sessionEnd)")
    elif kind == "sessionStart":
        emit(f"[{ts}] [{name}] SESSION_START")
    # 'stop' kind is intentionally ignored; idle is detected via lastBody polling

def follow_workstream():
    f = open(WORKSTREAM, "r")
    f.seek(0, 2)
    while True:
        line = f.readline()
        if not line:
            time.sleep(0.5); continue
        line = line.strip()
        if not line: continue
        try: d = json.loads(line)
        except: continue
        handle_workstream(d)

def poll_idle():
    """Emit IDLE only when a session has been quiet for IDLE_DEBOUNCE_SEC AND
    cmux still flags it as Waiting. This filters out the rapid Waiting/Working
    flips between tool calls."""
    while True:
        try:
            d = json.load(open(SESSIONS))
        except Exception:
            time.sleep(IDLE_POLL_SEC); continue
        now = time.time()
        for sid, s in d.get("sessions", {}).items():
            sub = s.get("lastSubtitle", "")
            is_waiting = (sub == "Waiting")
            last_act = _last_activity.get(sid, 0)
            already_emitted = _idle_emitted.get(sid, False)
            quiet_for = now - last_act if last_act else 0
            if is_waiting and not already_emitted and quiet_for >= IDLE_DEBOUNCE_SEC:
                name = ws_name_for_session(sid)
                body = s.get("lastBody", "")
                emit(f"[{now_iso()}] [{name}] IDLE body={body!r} quiet={int(quiet_for)}s")
                _idle_emitted[sid] = True
        time.sleep(IDLE_POLL_SEC)

if __name__ == "__main__":
    refresh_map()
    open(OUT_PATH, "a").close()
    # Seed last_activity timestamps from the recent workstream so we don't
    # immediately emit IDLE for sessions that just paused a few seconds ago.
    now = time.time()
    try:
        with open(WORKSTREAM) as f:
            for line in f:
                if not line.strip(): continue
                try: d = json.loads(line)
                except: continue
                if d.get("source") != "claude": continue
                wsid = d.get("workstreamId","")
                if not wsid.startswith("claude-"): continue
                if d.get("kind") in ("toolUse", "userPrompt"):
                    _last_activity[wsid[len("claude-"):]] = now  # treat all as "just now"
    except Exception:
        pass
    # Sessions already at Waiting on startup: seed idle_emitted=True to avoid
    # a flood of IDLEs the first time poll_idle runs.
    try:
        d = json.load(open(SESSIONS))
        for sid, s in d.get("sessions", {}).items():
            if s.get("lastSubtitle","") == "Waiting":
                _idle_emitted[sid] = True
    except Exception:
        pass
    t = threading.Thread(target=poll_idle, daemon=True)
    t.start()
    follow_workstream()
