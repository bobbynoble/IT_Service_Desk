"""Create IT Service Desk Request table in Dataverse via Web API.

Uses MSAL device-code flow to authenticate as Robert@rnconsultancy.co.uk,
then calls EntityDefinitions and Attributes endpoints directly.
"""
import json
import sys
import os
import msal
import httpx

sys.stdout.reconfigure(line_buffering=True)
LOG = open(r"C:\Users\RobertNoble\Desktop\dataverse_create.log", "w", buffering=1)

_orig_print = print
def print(*args, **kwargs):
    _orig_print(*args, **kwargs)
    _orig_print(*args, **kwargs, file=LOG)
    LOG.flush()

TOKEN_CACHE_FILE = r"C:\Users\RobertNoble\Desktop\dataverse_token_cache.bin"

ENV_URL   = "https://rnobleconsultancydefault.crm11.dynamics.com"
API_BASE  = f"{ENV_URL}/api/data/v9.2"
TENANT_ID = "common"
CLIENT_ID = "51f81489-12ee-4a9e-aaae-a2591f45987d"  # Microsoft Power Apps public client
SCOPE     = [f"{ENV_URL}/.default"]

def get_token():
    cache = msal.SerializableTokenCache()
    if os.path.exists(TOKEN_CACHE_FILE):
        cache.deserialize(open(TOKEN_CACHE_FILE, "r").read())

    app = msal.PublicClientApplication(CLIENT_ID,
        authority=f"https://login.microsoftonline.com/{TENANT_ID}",
        token_cache=cache)

    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPE, account=accounts[0])
        if result and "access_token" in result:
            print(f"Using cached token for {accounts[0]['username']}")
            if cache.has_state_changed:
                open(TOKEN_CACHE_FILE, "w").write(cache.serialize())
            return result["access_token"]

    flow = app.initiate_device_flow(scopes=SCOPE)
    print("\n" + flow["message"] + "\n")
    sys.stdout.flush()
    result = app.acquire_token_by_device_flow(flow)
    if "access_token" not in result:
        print("Auth failed:", result.get("error_description"))
        sys.exit(1)
    if cache.has_state_changed:
        open(TOKEN_CACHE_FILE, "w").write(cache.serialize())
    return result["access_token"]

def api(token, method, path, body=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "OData-MaxVersion": "4.0",
        "OData-Version": "4.0",
        "Accept": "application/json",
        "Prefer": "return=representation",
    }
    url = f"{API_BASE}/{path.lstrip('/')}"
    timeout = 120 if "EntityDefinitions" in path and method == "POST" else 30
    r = httpx.request(method, url, headers=headers,
                      content=json.dumps(body) if body else None, timeout=timeout)
    if r.status_code >= 400:
        try:
            err = r.json().get("error", {})
            print(f"  ERROR {r.status_code}: {err.get('message', r.text[:300])}")
        except Exception:
            print(f"  ERROR {r.status_code}: {r.text[:300]}")
        return None
    return r.json() if r.content else {}

def label(text):
    return {"@odata.type": "Microsoft.Dynamics.CRM.Label",
            "LocalizedLabels": [{"@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
                                 "Label": text, "LanguageCode": 1033}]}

def main():
    print("Authenticating to Dataverse...")
    token = get_token()
    print("Authenticated.\n")

    print("Step 1: Creating table rnc_ITServiceDeskRequest...")
    table_def = {
        "SchemaName": "rnc_ITServiceDeskRequest",
        "DisplayName": label("IT Service Desk Request"),
        "DisplayCollectionName": label("IT Service Desk Requests"),
        "Description": label("Tracks IT service desk / helpdesk support requests"),
        "OwnershipType": "UserOwned",
        "HasNotes": True,
        "HasActivities": False,
        "IsAuditEnabled": {"Value": True},
        "PrimaryNameAttribute": "rnc_name",
        "Attributes": [
            {
                "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
                "SchemaName": "rnc_name",
                "DisplayName": label("Ticket Reference"),
                "RequiredLevel": {"Value": "ApplicationRequired"},
                "MaxLength": 100,
                "IsPrimaryName": True,
                "IsAuditEnabled": {"Value": True},
            }
        ],
    }
    r = api(token, "POST", "EntityDefinitions", table_def)
    if r is None:
        print("Table may already exist — continuing with attribute creation...")
    else:
        print(f"  Table created: MetadataId={r.get('MetadataId')}")

    entity = "rnc_itservicedeskrequest"

    print("\nStep 2: Adding text columns...")
    text_cols = [
        ("rnc_requestername",  "Requester Name",     200, "ApplicationRequired", True,  "Text"),
        ("rnc_requesteremail", "Requester Email",     200, "ApplicationRequired", True,  "Email"),
        ("rnc_department",     "Department",          200, "None",                False, "Text"),
        ("rnc_contactnumber",  "Contact Number",       50, "None",                False, "Text"),
        ("rnc_description",    "Description",        2000, "ApplicationRequired", True,  "TextArea"),
        ("rnc_resolutionnotes","Resolution Notes",   4000, "None",                False, "TextArea"),
        ("rnc_assignedto",     "Assigned To",          200, "None",                False, "Text"),
        ("rnc_deviceassettag", "Device / Asset Tag",   100, "None",                False, "Text"),
    ]
    for schema, display, maxlen, req, audit, fmt in text_cols:
        body = {
            "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
            "SchemaName": schema,
            "DisplayName": label(display),
            "RequiredLevel": {"Value": req},
            "MaxLength": maxlen,
            "FormatName": {"Value": fmt},
            "IsAuditEnabled": {"Value": audit},
        }
        r = api(token, "POST", f"EntityDefinitions(LogicalName='{entity}')/Attributes", body)
        status = "OK" if r is not None else "skipped/exists"
        print(f"  {schema}: {status}")

    print("\nStep 3: Adding date columns...")
    date_cols = [
        ("rnc_datereported", "Date Reported", "ApplicationRequired", True),
        ("rnc_dueby",        "Due By",        "None",                True),
        ("rnc_dateresolved", "Date Resolved", "None",                True),
    ]
    for schema, display, req, audit in date_cols:
        body = {
            "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
            "SchemaName": schema,
            "DisplayName": label(display),
            "RequiredLevel": {"Value": req},
            "Format": "DateAndTime",
            "DateTimeBehavior": {"Value": "UserLocal"},
            "IsAuditEnabled": {"Value": audit},
        }
        r = api(token, "POST", f"EntityDefinitions(LogicalName='{entity}')/Attributes", body)
        print(f"  {schema}: {'OK' if r is not None else 'skipped/exists'}")

    print("\nStep 4: Adding choice columns...")
    choices = [
        ("rnc_category", "Category", [
            (581080000, "Hardware"),
            (581080001, "Software"),
            (581080002, "Network"),
            (581080003, "Access & Accounts"),
            (581080004, "Email"),
            (581080005, "Printer"),
            (581080006, "Telephony"),
            (581080007, "Other"),
        ], "ApplicationRequired", None),
        ("rnc_priority", "Priority", [
            (581080000, "Low"),
            (581080001, "Medium"),
            (581080002, "High"),
            (581080003, "Critical"),
        ], "ApplicationRequired", 581080001),
        ("rnc_status", "Status", [
            (581080000, "New"),
            (581080001, "In Progress"),
            (581080002, "On Hold"),
            (581080003, "Resolved"),
            (581080004, "Closed"),
            (581080005, "Cancelled"),
        ], "ApplicationRequired", 581080000),
    ]
    for schema, display, options, req, default in choices:
        body = {
            "@odata.type": "Microsoft.Dynamics.CRM.PicklistAttributeMetadata",
            "SchemaName": schema,
            "DisplayName": label(display),
            "RequiredLevel": {"Value": req},
            "IsAuditEnabled": {"Value": True},
            "OptionSet": {
                "@odata.type": "Microsoft.Dynamics.CRM.OptionSetMetadata",
                "IsGlobal": False,
                "OptionSetType": "Picklist",
                "Options": [{"Value": v, "Label": label(l)} for v, l in options],
            },
        }
        if default is not None:
            body["DefaultFormValue"] = default
        r = api(token, "POST", f"EntityDefinitions(LogicalName='{entity}')/Attributes", body)
        print(f"  {schema}: {'OK' if r is not None else 'skipped/exists'}")

    print("\nDone! View the table at:")
    print("  https://make.powerapps.com -> Tables -> IT Service Desk Request")

if __name__ == "__main__":
    main()
