$pac = "C:\Users\RobertNoble\AppData\Local\Microsoft\PowerAppsCLI\Microsoft.PowerApps.CLI.2.9.3\tools\pac.exe"
$envUrl = "https://rnobleconsultancydefault.crm11.dynamics.com"

Write-Host "=== Step 1: Authenticate ===" -ForegroundColor Cyan
& $pac auth create --url $envUrl --name "RNConsultancy"

Write-Host "`n=== Step 2: Confirm environment ===" -ForegroundColor Cyan
& $pac env who

Write-Host "`n=== Step 3: Create IT Service Desk solution ===" -ForegroundColor Cyan
# Create a solution to hold the table (best practice - keeps it portable)
& $pac solution create --name "ITServiceDeskAgent" --publisher-name "RNConsultancy" --publisher-prefix "rnc"

Write-Host "`n=== Step 4: Create the IT Service Desk Request table ===" -ForegroundColor Cyan

# Build the table definition JSON
$tableJson = @'
{
  "SchemaName": "rnc_ITServiceDeskRequest",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{ "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "IT Service Desk Request", "LanguageCode": 1033 }]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{ "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "IT Service Desk Requests", "LanguageCode": 1033 }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{ "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "Tracks IT service desk / helpdesk support requests", "LanguageCode": 1033 }]
  },
  "OwnershipType": "UserOwned",
  "TableType": "Standard",
  "IsAuditEnabled": { "Value": true },
  "HasActivities": false,
  "HasNotes": true
}
'@

# Use Dataverse Web API to create the table
Write-Host "Authenticating to Dataverse Web API..." -ForegroundColor Yellow

# Get access token via pac
$tokenOutput = & $pac auth token 2>&1
$token = ($tokenOutput | Where-Object { $_ -match "^eyJ" }) | Select-Object -First 1

if (-not $token) {
    Write-Host "Getting token via az cli fallback..." -ForegroundColor Yellow
    $token = (az account get-access-token --resource $envUrl --query accessToken -o tsv 2>$null)
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "Accept" = "application/json"
}

$apiBase = "$envUrl/api/data/v9.2"

Write-Host "Creating table..." -ForegroundColor Yellow
try {
    $resp = Invoke-RestMethod -Uri "$apiBase/EntityDefinitions" -Method POST -Headers $headers -Body $tableJson
    Write-Host "Table created: $($resp.MetadataId)" -ForegroundColor Green
} catch {
    Write-Host "Table may already exist or error: $_" -ForegroundColor Yellow
}

# Column definitions
$columns = @(
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_RequesterName"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Requester Name"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "ApplicationRequired" }
            MaxLength = 200
            FormatName = @{ Value = "Text" }
            IsAuditEnabled = @{ Value = $true }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_RequesterEmail"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Requester Email"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "ApplicationRequired" }
            MaxLength = 200
            FormatName = @{ Value = "Email" }
            IsAuditEnabled = @{ Value = $true }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_Department"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Department"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            MaxLength = 200
            FormatName = @{ Value = "Text" }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_ContactNumber"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Contact Number"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            MaxLength = 50
            FormatName = @{ Value = "Text" }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_Description"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Description"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "ApplicationRequired" }
            MaxLength = 2000
            FormatName = @{ Value = "TextArea" }
            IsAuditEnabled = @{ Value = $true }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_ResolutionNotes"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Resolution Notes"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            MaxLength = 4000
            FormatName = @{ Value = "TextArea" }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_AssignedTo"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Assigned To"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            MaxLength = 200
            FormatName = @{ Value = "Text" }
        }
    },
    @{
        type = "String"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "rnc_DeviceAssetTag"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Device / Asset Tag"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            MaxLength = 100
            FormatName = @{ Value = "Text" }
        }
    },
    @{
        type = "DateTime"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            SchemaName = "rnc_DateReported"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Date Reported"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "ApplicationRequired" }
            Format = "DateAndTime"
            IsAuditEnabled = @{ Value = $true }
        }
    },
    @{
        type = "DateTime"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            SchemaName = "rnc_DueBy"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Due By"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            Format = "DateAndTime"
            IsAuditEnabled = @{ Value = $true }
        }
    },
    @{
        type = "DateTime"
        body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            SchemaName = "rnc_DateResolved"
            DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Date Resolved"; LanguageCode = 1033 }) }
            RequiredLevel = @{ Value = "None" }
            Format = "DateAndTime"
            IsAuditEnabled = @{ Value = $true }
        }
    }
)

Write-Host "`n=== Step 5: Adding columns ===" -ForegroundColor Cyan

# Get the entity logical name
$entityLogical = "rnc_itservicedeskrequest"

foreach ($col in $columns) {
    $colName = $col.body.SchemaName
    Write-Host "  Adding column: $colName" -ForegroundColor Yellow
    try {
        $body = $col.body | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri "$apiBase/EntityDefinitions(LogicalName='$entityLogical')/Attributes" `
            -Method POST -Headers $headers -Body $body | Out-Null
        Write-Host "  OK: $colName" -ForegroundColor Green
    } catch {
        Write-Host "  ! $colName - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create choice columns (picklists) for Category, Priority and Status
Write-Host "`n=== Step 6: Adding choice columns (Category, Priority & Status) ===" -ForegroundColor Cyan

$categoryChoice = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
    SchemaName = "rnc_Category"
    DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Category"; LanguageCode = 1033 }) }
    RequiredLevel = @{ Value = "ApplicationRequired" }
    IsAuditEnabled = @{ Value = $true }
    OptionSet = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        IsGlobal = $false
        OptionSetType = "Picklist"
        Options = @(
            @{ Value = 100000000; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Hardware"; LanguageCode = 1033 }) } }
            @{ Value = 100000001; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Software"; LanguageCode = 1033 }) } }
            @{ Value = 100000002; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Network"; LanguageCode = 1033 }) } }
            @{ Value = 100000003; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Access & Accounts"; LanguageCode = 1033 }) } }
            @{ Value = 100000004; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Email"; LanguageCode = 1033 }) } }
            @{ Value = 100000005; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Printer"; LanguageCode = 1033 }) } }
            @{ Value = 100000006; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Telephony"; LanguageCode = 1033 }) } }
            @{ Value = 100000007; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Other"; LanguageCode = 1033 }) } }
        )
    }
} | ConvertTo-Json -Depth 10

$priorityChoice = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
    SchemaName = "rnc_Priority"
    DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Priority"; LanguageCode = 1033 }) }
    RequiredLevel = @{ Value = "ApplicationRequired" }
    IsAuditEnabled = @{ Value = $true }
    DefaultFormValue = 100000001
    OptionSet = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        IsGlobal = $false
        OptionSetType = "Picklist"
        Options = @(
            @{ Value = 100000000; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Low"; LanguageCode = 1033 }) } }
            @{ Value = 100000001; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Medium"; LanguageCode = 1033 }) } }
            @{ Value = 100000002; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "High"; LanguageCode = 1033 }) } }
            @{ Value = 100000003; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Critical"; LanguageCode = 1033 }) } }
        )
    }
} | ConvertTo-Json -Depth 10

$statusChoice = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
    SchemaName = "rnc_Status"
    DisplayName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Status"; LanguageCode = 1033 }) }
    RequiredLevel = @{ Value = "ApplicationRequired" }
    IsAuditEnabled = @{ Value = $true }
    DefaultFormValue = 100000000
    OptionSet = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        IsGlobal = $false
        OptionSetType = "Picklist"
        Options = @(
            @{ Value = 100000000; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "New"; LanguageCode = 1033 }) } }
            @{ Value = 100000001; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "In Progress"; LanguageCode = 1033 }) } }
            @{ Value = 100000002; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "On Hold"; LanguageCode = 1033 }) } }
            @{ Value = 100000003; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Resolved"; LanguageCode = 1033 }) } }
            @{ Value = 100000004; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Closed"; LanguageCode = 1033 }) } }
            @{ Value = 100000005; Label = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Cancelled"; LanguageCode = 1033 }) } }
        )
    }
} | ConvertTo-Json -Depth 10

foreach ($choice in @(@{name="rnc_Category"; body=$categoryChoice}, @{name="rnc_Priority"; body=$priorityChoice}, @{name="rnc_Status"; body=$statusChoice})) {
    Write-Host "  Adding choice: $($choice.name)" -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$apiBase/EntityDefinitions(LogicalName='$entityLogical')/Attributes" `
            -Method POST -Headers $headers -Body $choice.body | Out-Null
        Write-Host "  OK: $($choice.name)" -ForegroundColor Green
    } catch {
        Write-Host "  ! $($choice.name) - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Table 'rnc_ITServiceDeskRequest' created in $envUrl" -ForegroundColor Green
Write-Host "View it at: https://make.powerapps.com -> Tables -> IT Service Desk Request" -ForegroundColor Cyan
