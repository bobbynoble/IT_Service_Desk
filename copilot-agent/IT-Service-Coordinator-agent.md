# IT Service Coordinator — Copilot Studio agent

Agent description and setup for a Copilot Studio conversational agent that
lets staff log, triage, and track tickets in the **IT Service Desk Request**
Dataverse table (`rnc_itservicedeskrequest`) by talking to it in plain
language.

This is a Copilot Studio agent, not a Microsoft 365 Copilot declarative
plugin — it's built in the Copilot Studio maker portal and talks to the
table via the built-in **Microsoft Dataverse** connector, so no custom API
or backend is required.

---

## 1. Fields to paste into Copilot Studio

Go to **copilotstudio.microsoft.com** → your environment (must be the same
Dataverse environment the table lives in, `rnobleconsultancydefault`) →
**Create** → **New agent** → **Skip to configure** (or "Create from blank").

**Name**
```
IT Service Coordinator
```

**Description**
```
Helps staff log, triage, and track IT Service Desk requests — creating
tickets, checking status, and surfacing what's overdue or high priority —
backed by the IT Service Desk Request Dataverse table.
```

**Instructions** (paste into the agent's Instructions/System prompt field
under Settings → Generative AI → Instructions)
```
You are an IT service desk coordinator assistant. You help staff log new IT
support tickets and track existing ones stored in the "IT Service Desk
Request" Dataverse table (rnc_itservicedeskrequest).

Key behaviours:
1. When logging a new ticket, always collect: requester name, requester
   email, a category (Hardware, Software, Network, Access & Accounts,
   Email, Printer, Telephony, Other), a priority (Low, Medium, High,
   Critical — ask about impact/urgency if unclear, default to Medium), and
   a description of the issue. Department, contact number, and device/asset
   tag are optional — ask only if relevant to the issue.
2. When creating a ticket, set Status to "New" and Date Reported to now.
   Generate a short, human-readable Ticket Reference if the user doesn't
   give one (e.g. "ITSD-<short date/time or sequence>").
3. When asked what's outstanding, overdue, or high priority, list rows
   filtered to Status not in (Resolved, Closed, Cancelled) and present the
   results as a table: Ticket Reference, Requester, Category, Priority,
   Status, Date Reported, Due By.
4. If a new ticket is Critical priority, flag it clearly in your reply and
   ask the user if they want it escalated immediately.
5. When resolving a ticket, ask for resolution notes, then set Status to
   "Resolved" and Date Resolved to now.
6. Only surface ticket details relevant to the current request — don't dump
   unrelated tickets' contact details into a reply.
7. Be concise, professional, and calm — like a competent service desk
   coordinator, not a chatty assistant.
```

**Conversation starters**
```
Log a new IT support ticket
What tickets are still open?
Show me anything marked Critical
What's overdue against SLA?
Mark ticket <reference> as resolved
```

---

## 2. Wire up the Dataverse table as actions

In the agent's **Actions** tab:

1. **Add an action** → **Connectors** → search **Microsoft Dataverse**.
2. Add these four actions (all against table **IT Service Desk Requests**,
   environment `rnobleconsultancydefault`):

   | Action | Dataverse operation | Used for |
   |---|---|---|
   | Create Request | Add a new row | Logging a new ticket |
   | List Requests | List rows (with `$filter`/`$orderby`) | "What's open / overdue / Critical" |
   | Get Request | Get a row by ID | Looking up one ticket by reference |
   | Resolve Request | Update a row | Recording resolution notes + closing |

3. For each action, in the generated Power Automate flow / connector step,
   map the table to `rnc_itservicedeskrequest` and expose these columns as
   inputs/outputs so the model can read and write them:

   `rnc_name` (Ticket Reference), `rnc_requestername`, `rnc_requesteremail`,
   `rnc_department`, `rnc_contactnumber`, `rnc_category`, `rnc_priority`,
   `rnc_status`, `rnc_description`, `rnc_resolutionnotes`, `rnc_assignedto`,
   `rnc_deviceassettag`, `rnc_datereported`, `rnc_dueby`, `rnc_dateresolved`.

4. Rename each action with a clear, plain-English name and description (the
   ones in the table above) — Copilot Studio uses these names/descriptions,
   not the raw connector operation, to decide when to call each one.

5. In the **List Requests** action, expose a `$filter` and `$orderby` input
   so the model can ask for things like
   `statuscode ne 100000004 and statuscode ne 100000003` (excludes
   Cancelled/Closed) sorted by `rnc_priority desc`.

---

## 3. Test it

Use the Copilot Studio test pane and try each conversation starter, plus:

- "Log a ticket for Jane Doe, jane.doe@nhs.net, her laptop won't turn on,
  high priority"
- "What's still open?"
- "Anything Critical right now?"
- "Mark ITSD-... as resolved, fixed by replacing the power adapter"

Then **Publish** and add a channel (Teams, a website, or Microsoft 365
Copilot) once it behaves the way you want.
