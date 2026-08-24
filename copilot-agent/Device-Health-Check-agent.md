# Device Health Check Agent — Copilot Studio child agent

A read-only specialist agent, connected as a **child/connected agent** under
the **IT Service Coordinator**, that checks a specific device's health and
compliance in Microsoft Intune via Microsoft Graph. It doesn't touch
Dataverse or tickets — it only answers "what's the state of this device?"
when the parent agent calls it.

---

## 1. Fields to paste into Copilot Studio

Create it the same way as the parent: **copilotstudio.microsoft.com** →
same environment (`rnobleconsultancydefault`) → **Create** → **New agent**
→ **Skip to configure**.

**Name**
```
Device Health Check Agent
```

**Description**
```
The Device Health Check agent is a specialist child agent connected to the
IT Service Coordinator. When a ticket or conversation refers to a specific
device — by hostname, asset tag, serial number, or the user it belongs to —
it queries Microsoft Intune via Microsoft Graph to pull that device's
compliance state, last check-in time, OS version and build, encryption
status, and any failing compliance or configuration policies. The IT
Service Coordinator calls it whenever a hardware or software ticket
involves a managed device, so it can fold real device health data straight
into triage (e.g. "this laptop hasn't checked in for 12 days" or "it's
non-compliant — BitLocker is disabled") without anyone having to open the
Intune admin console. It only reads device state from Intune — it doesn't
create or modify Dataverse tickets itself; that stays with the parent
agent.
```

**Instructions** (Settings → Generative AI → Instructions)
```
You are a device health specialist agent connected to the IT Service
Coordinator as a child agent. You are invoked only to check the health of
a specific managed device in Microsoft Intune — you do not create, update,
or resolve IT Service Desk tickets yourself; that stays with the parent
agent.

Key behaviours:
1. When invoked, you'll be given a device identifier - hostname, serial
   number/asset tag, or a user's name/email. Look up the matching device
   in Intune via Microsoft Graph (deviceManagement/managedDevices),
   matching on deviceName, serialNumber, or the owning user's
   userPrincipalName/email.
2. If more than one device matches (e.g. a user with several devices),
   list them briefly and ask which one - unless the parent's request was
   clearly for all of that user's devices, in which case return all of
   them.
3. For each matched device, report: compliance state (compliant /
   noncompliant / in grace period), last check-in date and how many days
   ago that was, OS platform and version, encryption/BitLocker status, and
   any failing compliance or configuration policies with a plain-English
   reason.
4. Flag clearly if a device hasn't checked in for more than 7 days - that
   often means it's off, disconnected, or has an enrollment problem, which
   is itself useful triage information even without a policy failure.
5. If the device isn't found in Intune at all, say so plainly rather than
   guessing - it may be unmanaged, retired, or the identifier didn't
   match anything.
6. Keep responses factual and structured: a short summary line plus a
   compact list of the relevant details. Don't speculate about root cause
   beyond what the compliance/policy data actually shows.
7. You only read device data. Never attempt a remote action (wipe, sync,
   restart, retire) even if asked - that's out of scope for this agent.
8. Respond in a form the parent agent can drop straight into its own
   reply to the requester - no greetings, no sign-off, just the findings.
```

**Conversation starters** (for testing this agent standalone)
```
Is DESKTOP-FINANCE-12 compliant?
When did Jane Doe's laptop last check in?
Show me the compliance status for asset tag LAP-0042
List Sarah Khan's Intune devices
```

---

## 2. Register an Entra app for Graph/Intune access

This agent needs **application (app-only)** Graph permissions, since it
must be able to look up *any* device, not just ones belonging to whoever
is chatting. Delegated permissions won't do that.

1. **Azure Portal** → **Microsoft Entra ID** → **App registrations** →
   **New registration**.
   - Name: `IT Service Desk - Device Health Check Agent`
   - Supported account types: **Single tenant**
   - Redirect URI: leave blank (this uses client-credentials, not an
     interactive sign-in flow)
2. **API permissions** → **Add a permission** → **Microsoft Graph** →
   **Application permissions** → add:
   - `DeviceManagementManagedDevices.Read.All`
   - `User.Read.All` (only needed if you want to resolve a device by the
     owning user's display name rather than requiring their email/UPN)
   - Click **Grant admin consent for <tenant>** — application permissions
     don't work until this is done.
3. **Certificates & secrets** → **New client secret** → copy the secret
   value immediately (it's only shown once).
4. Note down, from the **Overview** page:
   - **Application (client) ID**
   - **Directory (tenant) ID**

Keep the client secret out of the repo — store it only in the custom
connector's connection (step 3 below) or a key vault, never committed here.

---

## 3. Create the custom connector for the Graph calls

Copilot Studio doesn't have a built-in "Intune" connector. Rather than
building the two Graph operations by hand, import the ready-made
definition: **[`intune-device-health-connector.json`](intune-device-health-connector.json)**.

1. Download/open `intune-device-health-connector.json` from this repo and
   replace `REPLACE_WITH_TENANT_ID` (in `securityDefinitions.graph_oauth.tokenUrl`)
   with your actual Directory (tenant) ID from step 2 above.
2. **make.powerapps.com** (same environment) → **Custom connectors** →
   **New custom connector** → **Import an OpenAPI file** → select the edited
   JSON file.
3. On the **General** step, host/base URL are already set from the file
   (`graph.microsoft.com` / `/v1.0`) — just confirm the connector icon/name
   if you want to change them.
4. On the **Security** step, it should show **OAuth 2.0** already selected
   with the token URL from the file. Fill in:
   - Client ID: the Application (client) ID from step 2 above
   - Client secret: the client secret value from step 2 above
   - Grant type: confirm it shows **Client Credentials** — this is what
     lets it look up any device, not just the signed-in user's
5. On the **Definition** step, you should see both operations already
   defined (`ListManagedDevices`, `GetManagedDevice`) with their
   parameters — no manual entry needed.
6. **Create connector**.
7. **Test** tab → **New connection** (this runs the client-credentials
   flow against your app registration) → run `ListManagedDevices` with no
   `$filter` to confirm it returns devices from your tenant.

If you'd rather build it by hand instead of importing, the equivalent
manual steps are: Custom connectors → New → Create from blank → Host
`graph.microsoft.com`, Base URL `/v1.0` → Security: OAuth 2.0, Azure Active
Directory, Client Credentials grant, Token URL
`https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token`, Scope
`https://graph.microsoft.com/.default` → Definition: add `GET
/deviceManagement/managedDevices` (with `$filter`, `$top`, `$select` query
params) and `GET /deviceManagement/managedDevices/{managedDeviceId}`.

---

## 4. Wire the connector into the agent

Back in Copilot Studio, on the **Device Health Check Agent**:

1. **Actions** tab → **Add an action** → **Connectors** → search
   `Intune Device Health` (the custom connector from step 3).
2. Add both `ListManagedDevices` and `GetManagedDevice`.
3. Rename/describe them plainly so the model calls the right one:
   - `ListManagedDevices` → "Find Intune devices by name, serial number, or
     owner"
   - `GetManagedDevice` → "Get full details for one Intune device by its
     ID"
4. Save, then test in the pane with one of the conversation starters above.

---

## 5. Connect it as a child agent under the IT Service Coordinator

1. Publish the **Device Health Check Agent** (top right → **Publish**) —
   it must be published before another agent can call it.
2. Open the **IT Service Coordinator** agent → **Agents** tab (next to
   Actions/Topics) → **Add an agent** → select **Device Health Check
   Agent**.
3. Copilot Studio will show the child agent's description (the one from
   §1 above) — this is what the parent uses to decide *when* to call it,
   so keep it accurate if you ever change what the child agent does.
4. Add a line to the **IT Service Coordinator**'s own instructions (in
   `IT-Service-Coordinator-agent.md`) so it actively uses this:
   ```
   8. If a ticket concerns a specific device and its health or compliance
      status would help triage or resolve it, call the connected "Device
      Health Check Agent" with whatever device identifier you have
      (hostname, asset tag, serial number, or the user's name/email) and
      fold its findings into your reply or into the ticket's description.
   ```
5. Publish the **IT Service Coordinator** again to pick up the new agent
   connection and instruction.

---

## 6. Test end-to-end

In the IT Service Coordinator's test pane:

- "Jane Doe's laptop won't turn on, can you check if it's even checking in
  to Intune?"
- "Log a ticket for DESKTOP-FINANCE-12, it keeps failing compliance, and
  tell me why"
- "Is asset tag LAP-0042 encrypted?"

Confirm the coordinator hands off to the Device Health Check Agent, gets a
structured answer back, and incorporates it into its reply (and, where
relevant, into the ticket description) rather than answering from a guess.
