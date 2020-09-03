
#=============================================================================
#
#    INIT
#
#=============================================================================


#
#
function Get-ManagementGroup()
{
    param(
        [string]$groupname
    )

    $mgmGroup = az account management-group show --name "$groupname" --expand

    return $mgmGroup
}

#
#
function New-DiagnosticSettings()
{
    param(
        $SubscriptionId
    )

    # Define settings for creating Diagnostic Settings
    #
    # $tenantId = "bd402493-0717-4f89-a565-39bdca08227b"
        
    # ARM Stuff
    #
    $templateFile = "C:\_Projects\CAB\DevOps\DiagnosticSettings\Azure_DiagnosticSettings-Create.json"
    $parameterFile = "C:\_Projects\CAB\DevOps\DiagnosticSettings\Azure_DiagnosticSettings-Create-Parameters.json"

    #
    #
    az deployment sub create --location Westeurope --template-file $templateFile  --parameters $parameterFile --subscription $SubscriptionId
}


#
#
class Subscription{
    [string]$Displayname
    [string]$Id
}

#=============================================================================
#
#    PROCESS
#
#=============================================================================

#
# az login

#******************************************************************************
# STEP 1:
#******************************************************************************

#
# Get managent groups in the root
$mgmGroupRoot = az account management-group show --name "CAB-Governance-Non-Prod" --expand

#
# Get subscriptions in the root
$subscriptions = @();

#
# Select id and displayname from returning data and add to the subscription list
$subscriptionIdNames = ($mgmGroupRoot | ConvertFrom-Json).children | Where-Object {$_.type -eq "/subscriptions"} | select id, displayname
foreach($subscriptionIdName in $subscriptionIdNames)
{
    $sub = new-object Subscription
    $sub.Displayname = $subscriptionIdName.displayname
    $sub.Id = $subscriptionIdName.id

    $subscriptions += $sub
}


#******************************************************************************
# STEP 2: 
#******************************************************************************

#
# Get a list management groups in the root
$mgmSubGroups = ($mgmGroupRoot | ConvertFrom-Json).children | Where-Object {$_.type -eq "/providers/Microsoft.Management/managementGroups"} | select displayname

#
# Get subscriptionsnames from management groups (iterate by management groups) + add to the subscription list
foreach($group in $mgmSubGroups)
{
    # Get management group data
    $mgmGroupData = Get-ManagementGroup -groupname $group.displayName

    # Get a list of subscription names and id's
    $subscriptionIdNames = ($mgmGroupData | ConvertFrom-Json).children | Where-Object {$_.type -eq "/subscriptions"} | select id, displayname
    foreach($subscriptionIdName in $subscriptionIdNames)
    {
        $sub = new-object Subscription
        $sub.Displayname = $subscriptionIdName.displayname
        $sub.Id = $subscriptionIdName.id

        $subscriptions += $sub
    }
}

#******************************************************************************
# STEP 3: Check if diagnostic settings exists... if not create!
#******************************************************************************

#
$workspaceName = "cabdevopslaworkspace"
$diagnosticSettingsName = "hubLogAnalytics"
#
$remove_DiagnosticSettings = $false;
$create_DiagnosticSettings = $true;

#cls
# Iterate through subscription list
foreach($subscription in $subscriptions)
{
    # Logging 
    $subscription.Displayname
    $subscription.id
    
    #$name = $subscription.Displayname
    $resource = $subscription.Id
    #
    $SubscriptionId = $subscription.id.Substring(15)
    #
    $diagnosticSettings_JSON = az monitor diagnostic-settings list --resource $($resource) 
    $numOfDiagSettings = ($diagnosticSettings_JSON | ConvertFrom-Json).value.count
    
    #
    if($numOfDiagSettings -eq 0)
    {
        
        # Create Diagnostic Settings!
        "-  No diagnostic settings found... create!"
        "- $($SubscriptionId)"
        ""
        # Create diagnostic settings...
        # 
        # New-DiagnosticSettings -SubscriptionId $SubscriptionId
    }
    elseif($numOfDiagSettings -gt 0)
    {
        # Check if settings exists, if not then create!
        "- Diagnostic settings found!"
        "- Check if named hubLogAnalytics (check scope!?)"
        ""
        
        #
        #
        $diagnosticSettings = $diagnosticSettings_JSON | ConvertFrom-Json

        "- $($diagnosticSettings.value.id)"
        ""
        #
        #
        if(($diagnosticSettings.value.workspaceid -like "*$($workspaceName)*") -and ($diagnosticSettings.value.name -eq "$($diagnosticSettingsName)"))
        {
            write-host "Log exists: " -ForegroundColor Green
            write-host "- Name.........: $($diagnosticSettings.value.name)" -ForegroundColor Green
            write-host "- Workspaceid..: $($diagnosticSettings.value.workspaceid)" -ForegroundColor Green
        }
        else
        {
            write-host "Log exists, but with wrong name or workspaceid: " -ForegroundColor Red
            write-host "- Name.........: $($diagnosticSettings.value.name)" -ForegroundColor Red
            write-host "- Workspaceid..: $($diagnosticSettings.value.workspaceid)" -ForegroundColor Red

            #
            #    
            if($remove_DiagnosticSettings -eq $true)
            {
                # Remove
            }

            #
            #
            if($create_DiagnosticSettings -eq $true)
            {
                # Create diagnostic settings
                #$SubscriptionId = $diagnosticSettings.value.id.Substring(15)
                $SubscriptionId
                #
                #
                New-DiagnosticSettings -SubscriptionId $SubscriptionId
            }

        }
    }
    ""
    "-----------------------------------"
    ""
}

