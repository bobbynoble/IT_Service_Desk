# IT Service Desk

Dataverse table and Power Platform solution for an IT Service Desk request app.

## Table: IT Service Desk Request (`rnc_itservicedeskrequest`)

| Column | Type | Notes |
|---|---|---|
| Ticket Reference (`rnc_name`) | Text | Primary column |
| Requester Name (`rnc_requestername`) | Text | Required |
| Requester Email (`rnc_requesteremail`) | Text (Email) | Required |
| Department (`rnc_department`) | Text | |
| Contact Number (`rnc_contactnumber`) | Text | |
| Category (`rnc_category`) | Choice | Hardware, Software, Network, Access & Accounts, Email, Printer, Telephony, Other |
| Priority (`rnc_priority`) | Choice | Low, Medium, High, Critical (default Medium) |
| Status (`rnc_status`) | Choice | New, In Progress, On Hold, Resolved, Closed, Cancelled (default New) |
| Description (`rnc_description`) | Text (multiline) | Required |
| Resolution Notes (`rnc_resolutionnotes`) | Text (multiline) | |
| Assigned To (`rnc_assignedto`) | Text | |
| Device / Asset Tag (`rnc_deviceassettag`) | Text | |
| Date Reported (`rnc_datereported`) | Date and Time | Required |
| Due By (`rnc_dueby`) | Date and Time | SLA target |
| Date Resolved (`rnc_dateresolved`) | Date and Time | |

Table and column audit is enabled; Notes are enabled on the table.

## Creating the table

Two equivalent ways to provision the table in Dataverse, both against solution
`ITServiceDeskAgent` (publisher `RNConsultancy`, prefix `rnc`):

- `scripts/create_itservicedesk_table.ps1` — PowerShell, authenticates via
  `pac auth` (Power Platform CLI) and calls the Dataverse Web API directly.
- `scripts/create_itservicedesk_table_api.py` — Python, authenticates via
  MSAL device-code flow (`pip install msal httpx`) and calls the same API.

Both scripts target `https://rnobleconsultancydefault.crm11.dynamics.com` —
update `$envUrl` / `ENV_URL` if you're provisioning into a different
environment. Both are idempotent-ish: re-running skips columns that already
exist.

## Solution source

`scripts/dataverse-solution/` is the unpacked (`pac solution unpack`) source
for the `ITServiceDeskAgent` solution — `solution.xml` (manifest) and
`customizations.xml` (entity/attribute/choice definitions). Pack it with:

```
pac solution pack --zipfile ITServiceDeskAgent.zip --folder scripts/dataverse-solution --packagetype Unmanaged
```

and import the resulting zip via `pac solution import` or the
make.powerapps.com solutions UI.
